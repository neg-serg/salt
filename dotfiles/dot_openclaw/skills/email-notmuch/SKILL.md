---
name: email-notmuch
description: Email management — search, read, tag, and send via notmuch + msmtp
requires:
  bins: ["notmuch", "msmtp", "mbsync"]
allowed-tools:
  - "Bash(notmuch:*)"
  - "Bash(msmtp:*)"
  - "Bash(mbsync:*)"
os: ["linux"]
---

# Email Management via notmuch + msmtp

Local email stack: **mbsync** syncs Gmail IMAP to `~/.local/mail/gmail/`, **notmuch** indexes and searches the maildir, **msmtp** sends outgoing mail, **goimapnotify** triggers sync on new mail.

## Check inbox (unread messages)

```bash
notmuch search tag:unread tag:inbox --format=json
```

Returns a JSON array. Each element contains: thread ID, timestamp, authors, subject, and tags.

## Search messages

```bash
notmuch search "QUERY" --format=json --limit=20
```

Query examples:

- `from:user@example.com` — by sender
- `subject:"meeting notes"` — by subject
- `date:1week..` — last week
- `tag:unread AND from:github.com` — combine conditions
- `to:me AND date:today` — messages received today

## Read a specific message

```bash
notmuch show --format=json id:MESSAGE_ID
```

Returns the full message with headers, body (prefer text/plain), and attachments list.

For full thread context:

```bash
notmuch show --format=json thread:THREAD_ID
```

## Sync mail now

Fetch new messages and index them:

```bash
mbsync gmail
notmuch new
```

Run both commands sequentially. This can take a few seconds.

## Tag management

- Mark as read: `notmuch tag -unread id:MESSAGE_ID`
- Mark as unread: `notmuch tag +unread id:MESSAGE_ID`
- Archive: `notmuch tag -inbox id:MESSAGE_ID`
- Star: `notmuch tag +flagged id:MESSAGE_ID`
- Custom tag: `notmuch tag +TAG id:MESSAGE_ID`
- Tag multiple messages by query: `notmuch tag +TAG -- QUERY`

## Sending email

**CRITICAL: always use draft-before-send workflow.**

**Step 1** — Compose the draft and present it to the user:

```
To: recipient@example.com
Subject: Re: Original subject

Message body here...
```

**Step 2** — Ask the user to confirm: "Send this email? [yes/no]"

**Step 3** — ONLY after explicit "yes" confirmation, send via:

```bash
printf 'To: %s\nSubject: %s\nContent-Type: text/plain; charset=utf-8\n\n%s' \
  "RECIPIENT" "SUBJECT" "BODY" | msmtp -a gmail RECIPIENT
```

For replies, include `In-Reply-To` and `References` headers from the original message:

```bash
printf 'To: %s\nSubject: %s\nIn-Reply-To: %s\nReferences: %s\nContent-Type: text/plain; charset=utf-8\n\n%s' \
  "RECIPIENT" "SUBJECT" "ORIGINAL_MSG_ID" "ORIGINAL_MSG_ID" "BODY" | msmtp -a gmail RECIPIENT
```

## Safety rules

- **NEVER** send email without showing the draft and getting explicit "yes" confirmation.
- **NEVER** delete messages. notmuch has no delete capability by design.
- Be careful with `notmuch tag` — tags are applied immediately and cannot be easily undone in bulk.
- When showing message summaries, truncate long bodies (show first 500 chars).
- For messages with attachments, list attachment names but do NOT try to extract them.
