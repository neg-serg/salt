"""Output formatters: text (with partial overwrite) and JSONL."""

import json
import sys
from dataclasses import dataclass


@dataclass
class TranscriptionResult:
    """A transcription result ready for output."""

    text: str
    result_type: str  # "partial" or "final"
    source_label: str
    lang: str
    timestamp: float  # seconds since session start


class OutputFormatter:
    """Base class for output formatting."""

    def __init__(self, dual_source: bool = False):
        self.dual_source = dual_source
        self._is_tty = sys.stdout.isatty()

    def emit(self, result: TranscriptionResult) -> None:
        raise NotImplementedError

    def flush(self) -> None:
        sys.stdout.flush()


class TextFormatter(OutputFormatter):
    """Plain text output with partial result overwriting on TTY."""

    def __init__(self, dual_source: bool = False, no_partial: bool = False):
        super().__init__(dual_source)
        self.no_partial = no_partial
        self._last_partial_len = 0

    def emit(self, result: TranscriptionResult) -> None:
        if result.result_type == "partial":
            if self.no_partial or not self._is_tty:
                return
            self._emit_partial(result)
        else:
            self._emit_final(result)

    def _format_prefix(self, result: TranscriptionResult) -> str:
        if self.dual_source:
            return f"[{result.source_label}] "
        return ""

    def _emit_partial(self, result: TranscriptionResult) -> None:
        prefix = self._format_prefix(result)
        line = f"{prefix}{result.text}"
        # Clear previous partial and overwrite
        sys.stdout.write(f"\r\033[2K{line}")
        sys.stdout.flush()
        self._last_partial_len = len(line)

    def _emit_final(self, result: TranscriptionResult) -> None:
        prefix = self._format_prefix(result)
        if self._last_partial_len > 0 and self._is_tty:
            # Clear the partial line
            sys.stdout.write("\r\033[2K")
        sys.stdout.write(f"{prefix}{result.text}\n")
        sys.stdout.flush()
        self._last_partial_len = 0


class JsonFormatter(OutputFormatter):
    """JSONL output, one JSON object per line."""

    def __init__(self, dual_source: bool = False, no_partial: bool = False):
        super().__init__(dual_source)
        self.no_partial = no_partial

    def emit(self, result: TranscriptionResult) -> None:
        if result.result_type == "partial" and self.no_partial:
            return
        obj = {
            "text": result.text,
            "type": result.result_type,
            "source": result.source_label,
            "lang": result.lang,
            "ts": round(result.timestamp, 3),
        }
        sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
        sys.stdout.flush()


def create_formatter(
    fmt: str = "text",
    dual_source: bool = False,
    no_partial: bool = False,
) -> OutputFormatter:
    """Create an output formatter by name."""
    if fmt == "json":
        return JsonFormatter(dual_source=dual_source, no_partial=no_partial)
    return TextFormatter(dual_source=dual_source, no_partial=no_partial)
