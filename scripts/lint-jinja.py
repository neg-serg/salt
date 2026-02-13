#!/usr/bin/env python3
"""Check Jinja2 syntax in Salt state files."""

import glob
import sys

import jinja2

env = jinja2.Environment(extensions=["jinja2.ext.do"])
errors = 0
files = sorted(glob.glob("states/*.sls"))

for f in files:
    try:
        env.parse(open(f).read())
    except jinja2.TemplateSyntaxError as e:
        print(f"\033[31m{f}:{e.lineno}: {e.message}\033[0m")
        errors += 1

print(f"Jinja2 syntax: checked {len(files)} files, {errors} errors")
sys.exit(1 if errors else 0)
