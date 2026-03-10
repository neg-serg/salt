"""Tests for output formatters."""

import io
import json
from unittest.mock import patch

from stream_stt.output import (
    JsonFormatter,
    TextFormatter,
    TranscriptionResult,
    create_formatter,
)


def _result(text="hello", rtype="final", source="mic", lang="en", ts=1.0):
    return TranscriptionResult(
        text=text,
        result_type=rtype,
        source_label=source,
        lang=lang,
        timestamp=ts,
    )


class TestTextFormatter:
    def test_final_single_source(self):
        out = io.StringIO()
        with patch("sys.stdout", out):
            fmt = TextFormatter(dual_source=False)
            fmt.emit(_result("Hello world"))
        assert "Hello world\n" in out.getvalue()
        assert "[mic]" not in out.getvalue()

    def test_final_dual_source(self):
        out = io.StringIO()
        with patch("sys.stdout", out):
            fmt = TextFormatter(dual_source=True)
            fmt.emit(_result("Hello world"))
        assert "[mic] Hello world\n" in out.getvalue()

    def test_partial_suppressed_in_pipe(self):
        out = io.StringIO()
        with patch("sys.stdout", out):
            fmt = TextFormatter(dual_source=False)
            fmt._is_tty = False
            fmt.emit(_result("partial text", rtype="partial"))
        assert out.getvalue() == ""

    def test_no_partial_flag(self):
        out = io.StringIO()
        with patch("sys.stdout", out):
            fmt = TextFormatter(dual_source=False, no_partial=True)
            fmt._is_tty = True
            fmt.emit(_result("partial text", rtype="partial"))
        assert out.getvalue() == ""


class TestJsonFormatter:
    def test_final_output(self):
        out = io.StringIO()
        with patch("sys.stdout", out):
            fmt = JsonFormatter(dual_source=False)
            fmt.emit(_result("Hello", ts=1.234))
        line = out.getvalue().strip()
        obj = json.loads(line)
        assert obj["text"] == "Hello"
        assert obj["type"] == "final"
        assert obj["source"] == "mic"
        assert obj["lang"] == "en"
        assert obj["ts"] == 1.234

    def test_partial_output(self):
        out = io.StringIO()
        with patch("sys.stdout", out):
            fmt = JsonFormatter(dual_source=False)
            fmt.emit(_result("Hel...", rtype="partial", ts=0.5))
        obj = json.loads(out.getvalue().strip())
        assert obj["type"] == "partial"

    def test_no_partial_flag(self):
        out = io.StringIO()
        with patch("sys.stdout", out):
            fmt = JsonFormatter(dual_source=False, no_partial=True)
            fmt.emit(_result("partial", rtype="partial"))
        assert out.getvalue() == ""

    def test_unicode_text(self):
        out = io.StringIO()
        with patch("sys.stdout", out):
            fmt = JsonFormatter()
            fmt.emit(_result("Привет мир", lang="ru"))
        obj = json.loads(out.getvalue().strip())
        assert obj["text"] == "Привет мир"
        assert obj["lang"] == "ru"


class TestCreateFormatter:
    def test_text(self):
        fmt = create_formatter("text")
        assert isinstance(fmt, TextFormatter)

    def test_json(self):
        fmt = create_formatter("json")
        assert isinstance(fmt, JsonFormatter)

    def test_dual_source(self):
        fmt = create_formatter("text", dual_source=True)
        assert fmt.dual_source is True

    def test_no_partial(self):
        fmt = create_formatter("text", no_partial=True)
        assert fmt.no_partial is True
