#!/usr/bin/env zsh
# Requires DUCKDNS_TOKEN and DUCKDNS_DOMAIN in environment
set -eu
: "${DUCKDNS_TOKEN:?DUCKDNS_TOKEN not set}"
: "${DUCKDNS_DOMAIN:?DUCKDNS_DOMAIN not set}"
response=$(curl -fsSL -d "domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=" "https://www.duckdns.org/update")
if [ "$response" != "OK" ]; then
    echo "DuckDNS update failed: $response" >&2
    exit 1
fi
