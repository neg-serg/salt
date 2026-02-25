#!/usr/bin/env python3
"""Lint QML files via qmllint with QuickShell type info.

Requires: qmllint (qt6-declarative), quickshell QML types installed.
Runs basic syntax + import checking (no -U flag — that produces ~460
false positives from Qt internals and unregistered project types).

Workaround: qmllint 1.0 doesn't understand `pragma ComponentBehavior`,
so files containing it are preprocessed to strip the pragma line.
"""

import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

QML_DIR = os.path.join("dotfiles", "dot_config", "quickshell")
QT_QML = "/usr/lib/qt6/qml"

# Type info files for qmllint to resolve imports
QMLTYPES = [
    os.path.join(QT_QML, "builtins.qmltypes"),
    os.path.join(QT_QML, "QtQuick", "plugins.qmltypes"),
    os.path.join(QT_QML, "Quickshell", "quickshell-core.qmltypes"),
]

# Import search paths
IMPORT_PATHS = [
    QT_QML,
    QML_DIR,
]

# Pragmas not supported by qmllint 1.0
_UNSUPPORTED_PRAGMA = re.compile(r"^pragma\s+ComponentBehavior\b.*$", re.MULTILINE)


def needs_preprocessing(content: str) -> bool:
    return bool(_UNSUPPORTED_PRAGMA.search(content))


def preprocess(content: str) -> str:
    return _UNSUPPORTED_PRAGMA.sub("", content)


def lint_files(files: list[str]) -> list[str]:
    """Run qmllint, return error lines."""
    cmd = ["qmllint"]
    for t in QMLTYPES:
        cmd += ["-i", t]
    for p in IMPORT_PATHS:
        cmd += ["-I", p]
    cmd += files

    result = subprocess.run(cmd, capture_output=True, text=True)
    output = (result.stdout + result.stderr).strip()
    if not output and result.returncode == 0:
        return []
    return [line for line in output.splitlines() if line.strip()]


def main():
    if not shutil.which("qmllint"):
        print("qmllint not found, skipping QML lint")
        return

    missing_types = [t for t in QMLTYPES if not os.path.exists(t)]
    if missing_types:
        print(f"Missing qmltypes (install qt6-declarative + quickshell): {missing_types}")
        print("Skipping QML lint")
        return

    all_files = sorted(glob.glob(os.path.join(QML_DIR, "**", "*.qml"), recursive=True))
    if not all_files:
        print("No QML files found")
        return

    # Split files: those needing pragma stripping vs clean ones
    clean_files = []
    pragma_files = []  # (original_path, content_without_pragma)
    for path in all_files:
        with open(path, encoding="utf-8") as f:
            content = f.read()
        if needs_preprocessing(content):
            pragma_files.append((path, preprocess(content)))
        else:
            clean_files.append(path)

    errors = []

    # Lint clean files in one batch
    if clean_files:
        errors.extend(lint_files(clean_files))

    # Lint pragma files via temp copies (preserving original paths in output)
    if pragma_files:
        with tempfile.TemporaryDirectory(prefix="qmllint-") as tmpdir:
            tmp_files = []
            tmp_to_orig = {}
            for orig_path, content in pragma_files:
                # Mirror directory structure so relative imports resolve
                rel = os.path.relpath(orig_path, QML_DIR)
                tmp_path = os.path.join(tmpdir, rel)
                os.makedirs(os.path.dirname(tmp_path), exist_ok=True)
                with open(tmp_path, "w", encoding="utf-8") as f:
                    f.write(content)
                tmp_files.append(tmp_path)
                tmp_to_orig[tmp_path] = orig_path

            # Also copy qmldir files so module resolution works
            for qmldir in glob.glob(os.path.join(QML_DIR, "**", "qmldir"), recursive=True):
                rel = os.path.relpath(qmldir, QML_DIR)
                dst = os.path.join(tmpdir, rel)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                if not os.path.exists(dst):
                    shutil.copy2(qmldir, dst)

            # Run with tmpdir as additional import path
            cmd = ["qmllint"]
            for t in QMLTYPES:
                cmd += ["-i", t]
            for p in IMPORT_PATHS:
                cmd += ["-I", p]
            cmd += ["-I", tmpdir]
            cmd += tmp_files

            result = subprocess.run(cmd, capture_output=True, text=True)
            output = (result.stdout + result.stderr).strip()
            if output:
                for line in output.splitlines():
                    if not line.strip():
                        continue
                    # Map temp paths back to originals
                    for tmp_path, orig_path in tmp_to_orig.items():
                        line = line.replace(tmp_path, orig_path)
                    errors.append(line)

    if errors:
        for line in errors:
            print(f"\033[31m{line}\033[0m")
        print(
            f"QML lint: {len(all_files)} files "
            f"({len(pragma_files)} preprocessed), {len(errors)} errors"
        )
        sys.exit(1)

    print(f"QML lint: {len(all_files)} files ({len(pragma_files)} preprocessed), 0 errors")


if __name__ == "__main__":
    main()
