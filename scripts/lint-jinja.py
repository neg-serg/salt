#!/usr/bin/env python3
"""Lint Salt state files: Jinja2 syntax, YAML validity, duplicate state IDs."""

import collections
import glob
import re
import sys

import jinja2
import jinja2.ext
import yaml

# --- Salt-specific Jinja2 tags ---
# Salt adds tags like {% import_yaml %}, {% load_yaml %} etc.
# Register them as no-op extensions so jinja2.parse() doesn't choke.


class SaltTagExtension(jinja2.ext.Extension):
    tags = {"import_yaml", "load_yaml", "import_json", "load_json", "import_text"}

    def parse(self, parser):
        tag = next(parser.stream)
        # Consume everything until block_end and return empty output
        while parser.stream.current.test("block_end") is False:
            next(parser.stream)
        return jinja2.nodes.Output([], lineno=tag.lineno)


def check_jinja_syntax(files):
    """Check Jinja2 syntax for .sls and .jinja files."""
    env = jinja2.Environment(extensions=["jinja2.ext.do", SaltTagExtension])
    errors = 0
    for f in files:
        try:
            with open(f) as fh:
                env.parse(fh.read())
        except jinja2.TemplateSyntaxError as e:
            print(f"\033[31mJinja: {f}:{e.lineno}: {e.message}\033[0m")
            errors += 1
    return errors


def _resolve_import_yaml(source, states_dir="states"):
    """Pre-scan template source for {% import_yaml %} and load the referenced files.

    Returns a dict of {var_name: loaded_data} to inject into the render context.
    """
    yaml_vars = {}
    for match in re.finditer(r"\{%-?\s*import_yaml\s+['\"]([^'\"]+)['\"]\s+as\s+(\w+)", source):
        rel_path, var_name = match.group(1), match.group(2)
        yaml_path = f"{states_dir}/{rel_path}"
        try:
            with open(yaml_path) as fh:
                yaml_vars[var_name] = yaml.safe_load(fh.read())
        except (FileNotFoundError, yaml.YAMLError):
            pass
    return yaml_vars


def check_duplicate_state_ids(sls_files):
    """Render .sls files with stub context and check for duplicate state IDs."""
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader("states"),
        extensions=["jinja2.ext.do", SaltTagExtension],
        undefined=jinja2.Undefined,
    )
    all_ids = []
    render_ok = 0
    for path in sls_files:
        name = path.removeprefix("states/")
        try:
            t = env.get_template(name)
            # Pre-load any {% import_yaml %} data so templates render correctly
            with open(path) as fh:
                yaml_vars = _resolve_import_yaml(fh.read())
            rendered = t.render(grains={"host": "lint-check"}, **yaml_vars)
            for doc in yaml.safe_load_all(rendered):
                if doc and isinstance(doc, dict):
                    all_ids.extend(doc.keys())
            render_ok += 1
        except Exception:
            # Files using Salt-only features ({% do %}, pillar, etc.) won't render
            pass

    dupes = [k for k, v in collections.Counter(all_ids).items() if v > 1]
    errors = 0
    for d in dupes:
        print(f"\033[31mDuplicate state ID: {d}\033[0m")
        errors += 1
    return errors, render_ok


def check_yaml_configs(config_files):
    """Validate YAML syntax in config files."""
    errors = 0
    for f in config_files:
        try:
            with open(f) as fh:
                yaml.safe_load(fh.read())
        except yaml.YAMLError as e:
            print(f"\033[31mYAML: {f}: {e}\033[0m")
            errors += 1
    return errors


def main():
    sls_files = sorted(glob.glob("states/*.sls"))
    jinja_files = sorted(glob.glob("states/*.jinja"))
    yaml_configs = sorted(
        glob.glob("states/configs/*.yaml")
        + glob.glob("states/configs/*.yml")
        + glob.glob("states/data/*.yaml")
    )
    all_jinja = sls_files + jinja_files

    total_errors = 0

    # 1. Jinja2 syntax
    jinja_errors = check_jinja_syntax(all_jinja)
    total_errors += jinja_errors
    print(f"Jinja2 syntax: {len(all_jinja)} files, {jinja_errors} errors")

    # 2. Duplicate state IDs
    dupe_errors, rendered = check_duplicate_state_ids(sls_files)
    total_errors += dupe_errors
    print(f"State IDs: {rendered} files rendered, {dupe_errors} duplicates")

    # 3. YAML config validation
    if yaml_configs:
        yaml_errors = check_yaml_configs(yaml_configs)
        total_errors += yaml_errors
        print(f"YAML configs: {len(yaml_configs)} files, {yaml_errors} errors")

    sys.exit(1 if total_errors else 0)


if __name__ == "__main__":
    main()
