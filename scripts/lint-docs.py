#!/usr/bin/env python3
"""Lint documentation: translation coverage and language consistency."""

import glob
import os
import re
import sys

# Directories containing translatable docs (relative to project root)
DOC_DIRS = ["docs"]

# Root-level files requiring .ru.md translation
ROOT_DOCS = ["README.md"]

# Files explicitly excluded from translation requirement
EXCLUDE = {"CLAUDE.md", "TODO.md"}

# Cyrillic Unicode range
_CYRILLIC_RE = re.compile(r"[\u0400-\u04FF]")

# Lines linking to .ru.md naturally contain Cyrillic link text — skip them
_RU_LINK_RE = re.compile(r"\.ru\.md\)")


def _collect_doc_dir_md():
    """Collect non-.ru.md files from DOC_DIRS."""
    return [
        f
        for d in DOC_DIRS
        for f in sorted(glob.glob(os.path.join(d, "*.md")))
        if not f.endswith(".ru.md")
    ]


def _find_english_docs():
    """Return list of English .md files that require translations."""
    docs = _collect_doc_dir_md()
    docs += [f for f in ROOT_DOCS if os.path.isfile(f)]
    return [f for f in docs if os.path.basename(f) not in EXCLUDE]


def _find_all_english_md():
    """Return list of ALL non-.ru.md files for Cyrillic checking."""
    docs = _collect_doc_dir_md()
    docs += [f for f in sorted(glob.glob("*.md")) if not f.endswith(".ru.md")]
    return docs


def check_translation_coverage():
    """Every English doc must have a .ru.md counterpart."""
    docs = _find_english_docs()
    errors = 0
    for path in docs:
        ru_path = path.replace(".md", ".ru.md")
        if not os.path.isfile(ru_path):
            print(f"\033[31mMissing translation: {ru_path}\033[0m")
            errors += 1
    return errors, len(docs)


def check_no_cyrillic():
    """English docs must not contain Cyrillic characters."""
    docs = _find_all_english_md()
    errors = 0
    files_checked = 0
    for path in docs:
        files_checked += 1
        with open(path, encoding="utf-8") as f:
            for lineno, line in enumerate(f, 1):
                if _CYRILLIC_RE.search(line) and not _RU_LINK_RE.search(line):
                    print(
                        f"\033[31mCyrillic in English doc: {path}:{lineno}: {line.rstrip()}\033[0m"
                    )
                    errors += 1
    return errors, files_checked


def main():
    total_errors = 0

    coverage_errors, doc_count = check_translation_coverage()
    total_errors += coverage_errors
    print(f"Translation coverage: {doc_count} docs, {coverage_errors} missing")

    cyrillic_errors, files_checked = check_no_cyrillic()
    total_errors += cyrillic_errors
    print(f"Language consistency: {files_checked} files, {cyrillic_errors} violations")

    sys.exit(1 if total_errors else 0)


if __name__ == "__main__":
    main()
