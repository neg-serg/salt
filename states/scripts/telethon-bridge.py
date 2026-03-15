#!/usr/bin/env python3
"""Telethon Bridge — standalone AI agent via Telegram MTProto + ProxyPilot.

Connects to Telegram as a userbot (personal account) and routes incoming
DMs to ProxyPilot's OpenAI-compatible API. Per-user conversation history
is persisted in SQLite with configurable context windowing.

Usage:
    telethon-bridge              # Run (requires initialized session)
    telethon-bridge-init         # First-time session setup (interactive)

Deployed as a systemd user service by Salt.
"""

import asyncio
import json
import logging
import os
import re
import signal
import sqlite3
import sys
import tempfile
import time
from pathlib import Path

import httpx
import yaml
from aiohttp import web
from telethon import TelegramClient, events, functions
from telethon.errors import FloodWaitError
from telethon.tl.types import MessageMediaDocument, MessageMediaPhoto

# ── Logging ──────────────────────────────────────────────────────────────
log = logging.getLogger("telethon-bridge")

CONFIG_PATH = Path.home() / ".telethon-bridge" / "config.yaml"


# ── SQLite Conversation Manager ──────────────────────────────────────────
class ConversationDB:
    """Per-user conversation history with context window trimming."""

    def __init__(self, db_path: str):
        self.db = sqlite3.connect(db_path)
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA synchronous=NORMAL")
        self.db.execute("""
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                token_count INTEGER DEFAULT 0,
                timestamp TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now')),
                telegram_msg_id INTEGER
            )
        """)
        self.db.execute("""
            CREATE INDEX IF NOT EXISTS idx_messages_user_ts
            ON messages (user_id, timestamp)
        """)
        self.db.commit()

    def add_message(
        self,
        user_id: int,
        role: str,
        content: str,
        token_count: int = 0,
        telegram_msg_id: int | None = None,
    ):
        self.db.execute(
            "INSERT INTO messages"
            " (user_id, role, content, token_count, telegram_msg_id)"
            " VALUES (?, ?, ?, ?, ?)",
            (user_id, role, content, token_count, telegram_msg_id),
        )
        self.db.commit()

    def get_history(
        self, user_id: int, max_messages: int = 100, max_tokens: int = 150_000
    ) -> list[dict]:
        """Get recent messages within the context window budget."""
        rows = self.db.execute(
            "SELECT role, content, token_count FROM messages"
            " WHERE user_id = ? ORDER BY timestamp DESC LIMIT ?",
            (user_id, max_messages),
        ).fetchall()

        result = []
        total_tokens = 0
        for role, content, tokens in rows:
            total_tokens += tokens
            if total_tokens > max_tokens:
                break
            result.append({"role": role, "content": content})

        result.reverse()
        return result

    def active_users_count(self, since_seconds: int = 3600) -> int:
        row = self.db.execute(
            "SELECT COUNT(DISTINCT user_id) FROM messages"
            " WHERE timestamp > strftime('%Y-%m-%dT%H:%M:%S', 'now', ?)",
            (f"-{since_seconds} seconds",),
        ).fetchone()
        return row[0] if row else 0

    def close(self):
        self.db.close()


# ── Markdown → Telegram HTML ─────────────────────────────────────────────
def md_to_telegram_html(text: str) -> str:
    """Convert common Markdown to Telegram-supported HTML.

    Handles: bold, italic, code blocks, inline code, links.
    Telegram HTML supports: <b>, <i>, <code>, <pre>, <a href>.
    """
    # Fenced code blocks (```lang\n...\n```)
    text = re.sub(
        r"```(\w*)\n(.*?)```",
        lambda m: f"<pre>{_escape_html(m.group(2))}</pre>",
        text,
        flags=re.DOTALL,
    )
    # Inline code (`...`)
    text = re.sub(
        r"`([^`]+)`",
        lambda m: f"<code>{_escape_html(m.group(1))}</code>",
        text,
    )
    # Bold (**...**)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    # Italic (*...*)
    text = re.sub(r"\*(.+?)\*", r"<i>\1</i>", text)
    # Links [text](url)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    return text


def _escape_html(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


# ── Message Splitting ────────────────────────────────────────────────────
TELEGRAM_MAX_LENGTH = 4096


def split_message(text: str) -> list[str]:
    """Split long messages at paragraph boundaries for Telegram's 4096 char limit."""
    if len(text) <= TELEGRAM_MAX_LENGTH:
        return [text]

    chunks = []
    while len(text) > TELEGRAM_MAX_LENGTH:
        # Try paragraph break
        split_at = text.rfind("\n\n", 0, TELEGRAM_MAX_LENGTH)
        if split_at == -1:
            # Try any newline
            split_at = text.rfind("\n", 0, TELEGRAM_MAX_LENGTH)
        if split_at == -1:
            # Hard split
            split_at = TELEGRAM_MAX_LENGTH
        chunks.append(text[:split_at])
        text = text[split_at:].lstrip("\n")

    if text:
        chunks.append(text)
    return chunks


# ── ProxyPilot AI Client ─────────────────────────────────────────────────
class AIClient:
    """Async client for ProxyPilot's OpenAI-compatible chat completions API."""

    def __init__(self, config: dict):
        ai = config["ai"]
        self.base_url = ai["base_url"].rstrip("/")
        self.api_key = ai["api_key"]
        self.default_model = ai["default_model"]
        self.fallback_model = ai.get("fallback_model", self.default_model)
        self.max_tokens = ai.get("max_tokens", 16384)
        self.timeout = ai.get("timeout", 120)
        self.last_ok = False
        self._client = httpx.AsyncClient(timeout=self.timeout)

    async def chat(
        self, messages: list[dict], model: str | None = None, max_tokens: int | None = None
    ) -> tuple[str, int]:
        """Send chat completion request. Returns (content, estimated_tokens)."""
        model = model or self.default_model
        max_tokens = max_tokens or self.max_tokens

        try:
            resp = await self._client.post(
                f"{self.base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model,
                    "messages": messages,
                    "max_tokens": max_tokens,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            content = data["choices"][0]["message"]["content"]
            usage = data.get("usage", {})
            tokens = usage.get("completion_tokens", len(content) // 4)
            self.last_ok = True
            return content, tokens

        except httpx.ConnectError:
            self.last_ok = False
            raise AIError("AI сервис временно недоступен (ProxyPilot не запущен)")
        except httpx.TimeoutException:
            self.last_ok = False
            raise AIError("Превышено время ожидания ответа от AI")
        except httpx.HTTPStatusError as e:
            self.last_ok = False
            if e.response.status_code == 429:
                raise AIError("Слишком много запросов, попробуйте позже")
            raise AIError(f"Ошибка AI сервиса: HTTP {e.response.status_code}")

    async def close(self):
        await self._client.aclose()


class AIError(Exception):
    pass


# ── Channel Monitor ──────────────────────────────────────────────────────
class ChannelMonitor:
    """Buffer channel messages and produce periodic AI digests."""

    def __init__(self, config: dict, ai: "AIClient", client: "TelegramClient"):
        self.ai = ai
        self.client = client
        self._buffers: dict[int, list[dict]] = {}  # channel_id → [{text, ts}]
        self._tasks: list[asyncio.Task] = []

        channels_cfg = config.get("channels", {})
        self._watches: list[dict] = channels_cfg.get("watch", [])

        # Resolve owner user_id for "owner_dm" routing
        allowlist = config.get("allowlist", [])
        self._owner_id: int | None = None
        for entry in allowlist:
            if entry.get("profile") == "owner":
                self._owner_id = int(entry["user_id"])
                break

    @property
    def channel_ids(self) -> list[int]:
        return [w["id"] for w in self._watches]

    @property
    def pending_count(self) -> int:
        return sum(len(msgs) for msgs in self._buffers.values())

    def buffer_message(self, channel_id: int, text: str):
        if channel_id not in self._buffers:
            self._buffers[channel_id] = []
        self._buffers[channel_id].append({"text": text, "ts": time.time()})

    def start_timers(self):
        for watch in self._watches:
            interval = watch.get("batch_interval", 600)
            task = asyncio.create_task(self._digest_loop(watch, interval))
            self._tasks.append(task)

    async def _digest_loop(self, watch: dict, interval: int):
        channel_id = watch["id"]
        channel_name = watch.get("name", str(channel_id))
        while True:
            await asyncio.sleep(interval)
            msgs = self._buffers.pop(channel_id, [])
            if not msgs:
                continue

            # Apply keyword filter
            keywords = watch.get("filter_keywords", [])
            if keywords:
                msgs = [m for m in msgs if any(kw.lower() in m["text"].lower() for kw in keywords)]
            if not msgs:
                continue

            action = watch.get("action", "summarize")
            combined = "\n\n".join(f"- {m['text']}" for m in msgs)

            if action == "summarize":
                prompt = (
                    f"Summarize these {len(msgs)} messages from"
                    f" channel '{channel_name}'."
                    f" Be concise, highlight key points:\n\n{combined}"
                )
            elif action == "filter":
                prompt = (
                    f"Filter and highlight the most important"
                    f" messages from channel '{channel_name}':"
                    f"\n\n{combined}"
                )
            else:
                prompt = (
                    f"Process these {len(msgs)} messages from"
                    f" channel '{channel_name}':\n\n{combined}"
                )

            try:
                digest, _ = await self.ai.chat(
                    [{"role": "user", "content": prompt}],
                    max_tokens=4096,
                )
            except AIError as e:
                log.error("Digest generation failed for %s: %s", channel_name, e)
                continue

            header = f"<b>📋 Digest: {_escape_html(channel_name)}</b> ({len(msgs)} messages)\n\n"
            html = header + md_to_telegram_html(digest)
            await self._send_to_output(watch, html)

    async def _send_to_output(self, watch: dict, html: str):
        output = watch.get("output", "owner_dm")
        chunks = split_message(html)

        try:
            if output == "owner_dm" and self._owner_id:
                target = self._owner_id
            elif output == "source":
                target = watch["id"]
            elif output.startswith("group:"):
                target = int(output.split(":", 1)[1])
            else:
                target = self._owner_id

            for i, chunk in enumerate(chunks):
                if i > 0:
                    await asyncio.sleep(0.3)
                await self.client.send_message(target, chunk, parse_mode="html")
        except Exception as e:
            log.error("Failed to send digest: %s", e)

    async def stop(self):
        for task in self._tasks:
            task.cancel()
        for task in self._tasks:
            try:
                await task
            except asyncio.CancelledError:
                pass


# ── Health HTTP Endpoint ─────────────────────────────────────────────────
class HealthServer:
    """Minimal HTTP health check server for salt-monitor integration."""

    def __init__(self, port: int, bridge: "TelethonBridge"):
        self.port = port
        self.bridge = bridge
        self._runner: web.AppRunner | None = None

    async def start(self):
        app = web.Application()
        app.router.add_get("/health", self._handle_health)
        self._runner = web.AppRunner(app, access_log=None)
        await self._runner.setup()
        site = web.TCPSite(self._runner, "127.0.0.1", self.port)
        await site.start()
        log.info("Health endpoint listening on 127.0.0.1:%d", self.port)

    async def _handle_health(self, _request: web.Request) -> web.Response:
        b = self.bridge
        body = {
            "connected": b.client.is_connected() if b.client else False,
            "proxypilot_ok": b.ai.last_ok if b.ai else False,
            "uptime_seconds": int(time.monotonic() - b.start_time),
            "active_users": b.db.active_users_count() if b.db else 0,
            "channels_watched": len(b.channel_monitor.channel_ids) if b.channel_monitor else 0,
            "pending_digest": b.channel_monitor.pending_count if b.channel_monitor else 0,
        }
        return web.json_response(body)

    async def stop(self):
        if self._runner:
            await self._runner.cleanup()


# ── Main Bridge ──────────────────────────────────────────────────────────
class TelethonBridge:
    """Core bridge: Telegram MTProto ↔ ProxyPilot AI."""

    def __init__(self, config: dict):
        self.config = config
        self.start_time = time.monotonic()

        # Telegram client
        tg = config["telegram"]
        session_path = os.path.expanduser(tg["session_path"])
        self.client = TelegramClient(session_path, int(tg["api_id"]), tg["api_hash"])

        # AI client
        self.ai = AIClient(config)

        # Conversation DB
        svc = config.get("service", {})
        db_path = os.path.expanduser(svc.get("db_path", "~/.telethon-bridge/conversations.db"))
        self.db = ConversationDB(db_path)

        # Allowlist: user_id → profile config
        self._allowlist: dict[int, dict] = {}
        profiles = config.get("profiles", {})
        for entry in config.get("allowlist", []):
            uid = int(entry["user_id"])
            profile_name = entry.get("profile", "guest")
            profile = profiles.get(profile_name, profiles.get("guest", {}))
            self._allowlist[uid] = profile

        # Channel monitor
        self.channel_monitor = ChannelMonitor(config, self.ai, self.client)

        # Group config
        groups_cfg = config.get("groups", {})
        self._allowed_groups: set[int] = set()
        for g in groups_cfg.get("allowed", []):
            self._allowed_groups.add(int(g) if isinstance(g, (int, str)) else int(g.get("id", 0)))
        self._group_trigger = groups_cfg.get("trigger", "mention_or_reply")

        # Automation rules
        auto_cfg = config.get("automation", {})
        self._forward_rules: list[dict] = auto_cfg.get("forward_rules", [])
        self._reaction_rules: list[dict] = auto_cfg.get("reaction_rules", [])

        # Media dir
        self._media_dir = Path(os.path.expanduser(svc.get("media_dir", "~/.telethon-bridge/media")))
        self._media_dir.mkdir(parents=True, exist_ok=True)

        # Owner ID for commands
        self._owner_id: int | None = None
        for entry in config.get("allowlist", []):
            if entry.get("profile") == "owner":
                self._owner_id = int(entry["user_id"])
                break

        # Health server
        health_port = svc.get("health_port", 8319)
        self.health = HealthServer(health_port, self)

    def _is_allowed(self, user_id: int) -> bool:
        return user_id in self._allowlist

    def _get_profile(self, user_id: int) -> dict:
        return self._allowlist.get(user_id, {})

    async def _handle_dm(self, event):
        """Handle incoming private messages from allowed users."""
        sender_id = event.sender_id

        if not self._is_allowed(sender_id):
            log.warning("Blocked message from unauthorized user_id=%d", sender_id)
            return

        # Check owner commands first
        if await self._handle_owner_commands(event):
            return

        # Voice transcription
        transcription = await self._handle_voice(event, sender_id, self._get_profile(sender_id))

        # Media download
        media_path = await self._handle_media_download(event)
        media_info = ""
        if media_path:
            p = Path(media_path)
            size_mb = p.stat().st_size / (1024 * 1024)
            media_info = f"\n[Attached file: {p.name}, {size_mb:.1f} MB]"

        text = event.message.text or ""
        if transcription:
            text = f"[Voice message transcription]: {transcription}\n\n{text}".strip()
        if media_info:
            text = f"{text}{media_info}".strip()

        if not text:
            return

        profile = self._get_profile(sender_id)
        ctx = profile.get("context_window", {})
        max_messages = ctx.get("max_messages", 100)
        max_tokens = ctx.get("max_tokens", 150_000)

        # Load conversation history
        history = self.db.get_history(sender_id, max_messages, max_tokens)

        # Build messages array
        system_prompt = profile.get("system_prompt", "You are a helpful AI assistant.")
        messages = [{"role": "system", "content": system_prompt}]
        messages.extend(history)
        messages.append({"role": "user", "content": text})

        # Estimate token count for user message
        user_tokens = len(text) // 4

        # Store user message
        self.db.add_message(sender_id, "user", text, user_tokens, event.message.id)

        # Call AI
        model = profile.get("model", self.config["ai"]["default_model"])
        try:
            response, resp_tokens = await self.ai.chat(messages, model=model)
        except AIError as e:
            await event.reply(str(e))
            return

        # Store AI response
        self.db.add_message(sender_id, "assistant", response, resp_tokens)

        # Send response
        await self._send_response(event, response)

    # ── Voice & Media Handling (US3) ────────────────────────────────────
    async def _handle_voice(self, event, sender_id: int, profile: dict) -> str | None:
        """Transcribe voice/audio message via whisper-cli. Returns text or None."""
        if not (event.message.voice or event.message.audio):
            return None

        with tempfile.NamedTemporaryFile(suffix=".ogg", delete=False) as tmp:
            tmp_path = tmp.name

        try:
            await self.client.download_media(event.message, file=tmp_path)
            proc = await asyncio.create_subprocess_exec(
                "whisper-cli",
                "-m",
                os.path.expanduser("~/.local/share/whisper/ggml-large-v3-turbo-q8_0.bin"),
                "-f",
                tmp_path,
                "-l",
                "auto",
                "--no-prints",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=60)
            if proc.returncode == 0:
                return stdout.decode().strip()
            log.warning("whisper-cli failed: %s", stderr.decode())
            return None
        except asyncio.TimeoutError:
            log.warning("Voice transcription timed out")
            return None
        except FileNotFoundError:
            log.warning("whisper-cli not found, skipping transcription")
            return None
        finally:
            Path(tmp_path).unlink(missing_ok=True)

    async def _handle_media_download(self, event) -> str | None:
        """Download media attachment, return file path."""
        if not event.message.media:
            return None
        if isinstance(event.message.media, (MessageMediaDocument, MessageMediaPhoto)):
            path = await self.client.download_media(event.message, file=str(self._media_dir))
            if path:
                log.info("Downloaded media: %s", path)
                return path
        return None

    async def _send_response(self, event, response: str):
        """Send AI response, splitting if needed. Supports file output markers."""
        # Check for file output markers: ```file:path\n...\n```
        file_match = re.search(r"```file:(.+?)\n(.*?)```", response, re.DOTALL)
        if file_match and event.sender_id == self._owner_id:
            filename = file_match.group(1).strip()
            content = file_match.group(2)
            with tempfile.NamedTemporaryFile(mode="w", suffix=f"_{filename}", delete=False) as tmp:
                tmp.write(content)
                tmp_path = tmp.name
            try:
                await self.client.send_file(event.chat_id, tmp_path, caption=f"📎 {filename}")
            finally:
                Path(tmp_path).unlink(missing_ok=True)
            # Remove the file block from the text response
            response = response[: file_match.start()] + response[file_match.end() :]
            response = response.strip()
            if not response:
                return

        html_response = md_to_telegram_html(response)
        chunks = split_message(html_response)

        for i, chunk in enumerate(chunks):
            try:
                if i == 0:
                    await event.reply(chunk, parse_mode="html")
                else:
                    await asyncio.sleep(0.3)
                    await event.respond(chunk, parse_mode="html")
            except FloodWaitError as e:
                log.warning("FloodWait: sleeping %d seconds", e.seconds)
                await asyncio.sleep(e.seconds)
                await event.respond(chunk, parse_mode="html")
            except Exception as e:
                log.warning("HTML send failed, falling back to plain text: %s", e)
                plain_chunks = split_message(response)
                for j, plain in enumerate(plain_chunks):
                    if j > 0:
                        await asyncio.sleep(0.3)
                    await event.respond(plain)
                break

    # ── Channel Message Handler (US2) ────────────────────────────────
    async def _handle_channel_message(self, event):
        """Buffer channel messages for periodic digest."""
        channel_id = event.chat_id
        text = event.message.text
        if not text:
            return

        # Check automation forward rules first
        for rule in self._forward_rules:
            if int(rule["source"]) == channel_id:
                keywords = rule.get("filter_keywords", [])
                if not keywords or any(kw.lower() in text.lower() for kw in keywords):
                    try:
                        await self.client.forward_messages(int(rule["target"]), event.message)
                        log.debug(
                            "Forwarded message from %d to %d", channel_id, int(rule["target"])
                        )
                    except Exception as e:
                        log.error("Forward failed %d→%d: %s", channel_id, int(rule["target"]), e)

        # Check reaction rules
        for rule in self._reaction_rules:
            if int(rule.get("channel", 0)) == channel_id:
                keywords = rule.get("keywords", [])
                if any(kw.lower() in text.lower() for kw in keywords):
                    reaction = rule.get("reaction", "👍")
                    try:
                        await self.client(
                            functions.messages.SendReactionRequest(
                                peer=event.chat_id,
                                msg_id=event.message.id,
                                reaction=[reaction],
                            )
                        )
                    except Exception as e:
                        log.debug("Reaction failed: %s", e)

        # Buffer for digest
        self.channel_monitor.buffer_message(channel_id, text)

    # ── Group Message Handler (US4) ──────────────────────────────────
    async def _handle_group_message(self, event):
        """Handle messages in authorized groups based on trigger mode."""
        chat_id = event.chat_id

        # Auto-leave unauthorized groups
        if chat_id not in self._allowed_groups:
            log.warning("Leaving unauthorized group %d", chat_id)
            try:
                await self.client.delete_dialog(chat_id)
            except Exception as e:
                log.error("Failed to leave group %d: %s", chat_id, e)
            return

        # Check trigger mode
        me = await self.client.get_me()
        triggered = False

        if self._group_trigger == "mention_or_reply":
            triggered = event.message.mentioned or (
                event.message.reply_to and event.message.reply_to.reply_to_msg_id
            )
        elif self._group_trigger == "reply_only":
            if event.message.reply_to:
                reply_msg = await event.get_reply_message()
                triggered = reply_msg and reply_msg.sender_id == me.id
        elif self._group_trigger == "command_prefix":
            triggered = event.message.text and event.message.text.startswith("/ai ")

        if not triggered:
            return

        text = event.message.text or ""
        if self._group_trigger == "command_prefix" and text.startswith("/ai "):
            text = text[4:]

        if not text.strip():
            return

        # Group context uses chat_id, not sender_id
        history = self.db.get_history(chat_id, max_messages=30, max_tokens=50_000)

        # Include replied-to message as context
        context_prefix = ""
        if event.message.reply_to:
            reply_msg = await event.get_reply_message()
            if reply_msg and reply_msg.text:
                context_prefix = f"[Replying to: {reply_msg.text}]\n\n"

        system_prompt = (
            "You are a helpful AI assistant in a group chat."
            " Be concise. Respond in the language used."
        )
        messages = [{"role": "system", "content": system_prompt}]
        messages.extend(history)
        messages.append({"role": "user", "content": context_prefix + text})

        user_tokens = len(text) // 4
        self.db.add_message(chat_id, "user", text, user_tokens, event.message.id)

        try:
            response, resp_tokens = await self.ai.chat(messages)
        except AIError as e:
            await event.reply(str(e))
            return

        self.db.add_message(chat_id, "assistant", response, resp_tokens)
        await self._send_response(event, response)

    # ── Owner Commands (US5) ─────────────────────────────────────────
    async def _handle_owner_commands(self, event) -> bool:
        """Handle special owner commands. Returns True if command was handled."""
        if event.sender_id != self._owner_id:
            return False

        text = (event.message.text or "").strip()
        if not text.startswith("/"):
            return False

        if text.startswith("/export"):
            parts = text.split()
            if len(parts) < 2:
                await event.reply("Usage: /export <chat_id> [limit]")
                return True
            chat_id = int(parts[1])
            limit = int(parts[2]) if len(parts) > 2 else 100

            export_dir = self._media_dir.parent / "exports"
            export_dir.mkdir(exist_ok=True)
            export_path = export_dir / f"export_{chat_id}_{int(time.time())}.json"

            messages = []
            async for msg in self.client.iter_messages(chat_id, limit=limit):
                messages.append(
                    {
                        "id": msg.id,
                        "date": msg.date.isoformat() if msg.date else None,
                        "sender_id": msg.sender_id,
                        "text": msg.text,
                    }
                )

            with open(export_path, "w") as f:
                json.dump(messages, f, ensure_ascii=False, indent=2)

            await self.client.send_file(
                event.chat_id,
                str(export_path),
                caption=f"📦 Export: {len(messages)} messages from {chat_id}",
            )
            log.info("Exported %d messages from %d", len(messages), chat_id)
            return True

        if text == "/clear":
            self.db.db.execute(
                "DELETE FROM messages WHERE user_id = ?",
                (event.sender_id,),
            )
            self.db.db.commit()
            await event.reply("🗑 Conversation history cleared.")
            return True

        return False

    async def run(self):
        """Start the bridge and run until stopped."""
        # Register DM handler
        self.client.add_event_handler(
            self._handle_dm,
            events.NewMessage(incoming=True, func=lambda e: e.is_private),
        )

        # Register channel handler if watches configured
        if self.channel_monitor.channel_ids:
            self.client.add_event_handler(
                self._handle_channel_message,
                events.NewMessage(chats=self.channel_monitor.channel_ids),
            )

        # Register group handler if groups configured
        if self._allowed_groups:
            self.client.add_event_handler(
                self._handle_group_message,
                events.NewMessage(incoming=True, func=lambda e: e.is_group),
            )

        # Start health server
        await self.health.start()

        # Connect to Telegram
        await self.client.start()
        me = await self.client.get_me()
        log.info("Connected as %s (id=%d)", me.first_name, me.id)

        # Start channel digest timers
        self.channel_monitor.start_timers()

        # Run until disconnected
        await self.client.run_until_disconnected()

    async def shutdown(self):
        """Graceful shutdown."""
        log.info("Shutting down...")
        await self.channel_monitor.stop()
        await self.health.stop()
        await self.ai.close()
        self.db.close()
        if self.client.is_connected():
            await self.client.disconnect()
        log.info("Shutdown complete")


# ── Entry Point ──────────────────────────────────────────────────────────
def main():
    if not CONFIG_PATH.exists():
        print(f"Error: config not found at {CONFIG_PATH}", file=sys.stderr)
        print("Run 'just apply telethon_bridge' to deploy.", file=sys.stderr)
        sys.exit(1)

    with open(CONFIG_PATH) as f:
        config = yaml.safe_load(f)

    # Logging
    svc = config.get("service", {})
    level = getattr(logging, svc.get("log_level", "info").upper(), logging.INFO)
    logging.basicConfig(
        level=level,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
        stream=sys.stderr,
    )

    bridge = TelethonBridge(config)

    # Signal handlers for graceful shutdown
    loop = asyncio.new_event_loop()

    def _signal_handler():
        loop.create_task(bridge.shutdown())

    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, _signal_handler)

    try:
        loop.run_until_complete(bridge.run())
    except KeyboardInterrupt:
        loop.run_until_complete(bridge.shutdown())
    finally:
        loop.close()


if __name__ == "__main__":
    main()
