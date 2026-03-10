"""CLI entry point for stream-stt."""

import argparse
import signal
import sys
from typing import Optional

from .audio import format_sources_table, list_sources


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="stream-stt",
        description="Streaming speech-to-text via PipeWire and whisper.cpp",
    )

    parser.add_argument(
        "-s",
        "--source",
        default=None,
        help="PipeWire source: node name, node ID, or 'default' (default: default mic)",
    )
    parser.add_argument(
        "-s2",
        "--source2",
        default=None,
        help="Second PipeWire source for dual capture",
    )
    parser.add_argument(
        "-l",
        "--label",
        default="mic",
        help="Label for primary source in output (default: mic)",
    )
    parser.add_argument(
        "-l2",
        "--label2",
        default="app",
        help="Label for second source in output (default: app)",
    )
    parser.add_argument(
        "-f",
        "--format",
        default="text",
        choices=["text", "json"],
        help="Output format (default: text)",
    )
    parser.add_argument(
        "-m",
        "--model",
        default=None,
        help="Path to whisper ggml model file (default: auto-detect)",
    )
    parser.add_argument(
        "--language",
        default="auto",
        help="Language code: en, ru, auto (default: auto)",
    )
    parser.add_argument(
        "--list-sources",
        action="store_true",
        help="List available PipeWire audio sources and exit",
    )
    parser.add_argument(
        "--step",
        type=int,
        default=3000,
        metavar="MS",
        help="Inference step interval in milliseconds (default: 3000)",
    )
    parser.add_argument(
        "--length",
        type=int,
        default=10000,
        metavar="MS",
        help="Audio window length in milliseconds (default: 10000)",
    )
    parser.add_argument(
        "--vad-threshold",
        type=float,
        default=0.6,
        help="VAD silence detection threshold 0.0-1.0 (default: 0.6)",
    )
    parser.add_argument(
        "--no-partial",
        action="store_true",
        help="Disable partial/intermediate results",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Print debug info to stderr",
    )

    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> None:
    args = parse_args(argv)

    # --list-sources: show available PipeWire sources and exit
    if args.list_sources:
        try:
            sources = list_sources()
        except RuntimeError as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(2)

        if not sources:
            print("No PipeWire audio sources found.", file=sys.stderr)
        else:
            print(format_sources_table(sources))
        sys.exit(0)

    # Validate args
    if args.source == "default":
        args.source = None

    # Import pipeline here to avoid loading whisper on --help/--list-sources
    from .pipeline import StreamingPipeline

    pipeline = StreamingPipeline(
        model_path=args.model,
        language=args.language,
        source=args.source,
        source2=args.source2,
        label=args.label,
        label2=args.label2,
        step_ms=args.step,
        length_ms=args.length,
        vad_threshold=args.vad_threshold,
        no_partial=args.no_partial,
        output_format=args.format,
        verbose=args.verbose,
    )

    # Signal handling for graceful shutdown
    def handle_signal(signum, frame):
        pipeline.stop()

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    # Run pipeline
    try:
        pipeline.run()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except RuntimeError as e:
        msg = str(e)
        if "pw-record" in msg or "PipeWire" in msg:
            print(f"PipeWire error: {e}", file=sys.stderr)
            sys.exit(2)
        elif "whisper" in msg.lower() or "model" in msg.lower():
            print(f"Whisper error: {e}", file=sys.stderr)
            sys.exit(3)
        else:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
