#!/usr/bin/env bash
# Requires DUCKDNS_TOKEN and DUCKDNS_DOMAIN in environment
set -eu
: "${DUCKDNS_TOKEN:?DUCKDNS_TOKEN not set}"
: "${DUCKDNS_DOMAIN:?DUCKDNS_DOMAIN not set}"
curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip="
