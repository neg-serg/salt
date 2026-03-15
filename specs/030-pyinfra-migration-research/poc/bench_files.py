# bench_files.py — pyinfra PoC: Jinja2 template deployment
#
# Part of 030-pyinfra-migration-research. NOT production code.
# Demonstrates pyinfra equivalent of Salt's file.managed with Jinja2 templates.
#
# Run: .venv/bin/pyinfra @local bench_files.py
#
# ---- Equivalent Salt YAML ----
# test1_config:
#   file.managed:
#     - name: /tmp/pyinfra-bench/test1.conf
#     - source: salt://configs/test1.conf.j2
#     - template: jinja
#     - user: neg
#     - group: neg
#     - mode: '0644'
#     - makedirs: True
#     - context:
#         app_name: benchmark-app
#         listen_port: 8080
#         log_level: info
#
# test2_config:
#   file.managed:
#     - name: /tmp/pyinfra-bench/test2.conf
#     - source: salt://configs/test2.conf.j2
#     - template: jinja
#     - user: neg
#     - group: neg
#     - mode: '0644'
#     - makedirs: True
#     - context:
#         db_host: localhost
#         db_port: 5432
#         db_name: benchdb
#
# test3_config:
#   file.managed:
#     - name: /tmp/pyinfra-bench/test3.conf
#     - source: salt://configs/test3.conf.j2
#     - template: jinja
#     - user: neg
#     - group: neg
#     - mode: '0600'
#     - makedirs: True
#     - context:
#         api_endpoint: http://127.0.0.1:8317
#         max_retries: 3
#         timeout_seconds: 30
# ----------------------------------

import os

from pyinfra.operations import files

DEPLOY_DIR = "/tmp/pyinfra-bench"
TEMPLATE_DIR = os.path.join(os.path.dirname(__file__), "templates")

# Ensure the target directory exists (Salt's makedirs: True equivalent).
files.directory(
    name="Ensure deploy directory exists",
    path=DEPLOY_DIR,
    user="neg",
    group="neg",
    mode="0755",
)

# Template 1: application config
files.template(
    name="Deploy test1.conf",
    src=os.path.join(TEMPLATE_DIR, "test1.conf.j2"),
    dest=os.path.join(DEPLOY_DIR, "test1.conf"),
    user="neg",
    group="neg",
    mode="0644",
    # Template variables — equivalent to Salt's context: block.
    app_name="benchmark-app",
    listen_port=8080,
    log_level="info",
)

# Template 2: database config
files.template(
    name="Deploy test2.conf",
    src=os.path.join(TEMPLATE_DIR, "test2.conf.j2"),
    dest=os.path.join(DEPLOY_DIR, "test2.conf"),
    user="neg",
    group="neg",
    mode="0644",
    db_host="localhost",
    db_port=5432,
    db_name="benchdb",
)

# Template 3: API config (restrictive permissions, like Salt secrets)
files.template(
    name="Deploy test3.conf",
    src=os.path.join(TEMPLATE_DIR, "test3.conf.j2"),
    dest=os.path.join(DEPLOY_DIR, "test3.conf"),
    user="neg",
    group="neg",
    mode="0600",
    api_endpoint="http://127.0.0.1:8317",
    max_retries=3,
    timeout_seconds=30,
)
