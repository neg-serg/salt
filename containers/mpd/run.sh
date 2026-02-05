#!/bin/bash
# Quick run script for MPD container
# Usage: ./run.sh [build|run|stop|logs|shell]

set -euo pipefail

CONTAINER_NAME="mpd"
IMAGE_NAME="localhost/mpd:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# User directories
MUSIC_DIR="${MUSIC_DIR:-$HOME/music}"
MPD_DATA_DIR="${MPD_DATA_DIR:-$HOME/.local/share/mpd}"
MPD_PLAYLISTS_DIR="${MPD_PLAYLISTS_DIR:-$HOME/.config/mpd/playlists}"
PULSE_SOCKET="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse/native"

build() {
    echo "Building MPD container..."
    podman build -t "$IMAGE_NAME" "$SCRIPT_DIR"
}

run() {
    # Create directories if they don't exist
    mkdir -p "$MPD_DATA_DIR" "$MPD_PLAYLISTS_DIR"

    # Create FIFO for visualizers if it doesn't exist
    if [[ ! -p /tmp/mpd.fifo ]]; then
        mkfifo /tmp/mpd.fifo 2>/dev/null || true
    fi

    echo "Starting MPD container..."
    podman run -d --rm \
        --name "$CONTAINER_NAME" \
        --userns=keep-id \
        -v "$MUSIC_DIR:/var/lib/mpd/music:ro" \
        -v "$MPD_DATA_DIR:/var/lib/mpd/data" \
        -v "$MPD_PLAYLISTS_DIR:/var/lib/mpd/playlists" \
        -v "$(dirname "$PULSE_SOCKET"):/run/user/1000/pulse" \
        -v "/tmp/mpd.fifo:/tmp/mpd.fifo" \
        -e "PULSE_SERVER=unix:/run/user/1000/pulse/native" \
        -p 6600:6600 \
        "$IMAGE_NAME"

    echo "MPD is running on port 6600"
    echo "Test with: MPD_HOST=127.0.0.1 mpc status"
}

stop() {
    echo "Stopping MPD container..."
    podman stop "$CONTAINER_NAME" 2>/dev/null || true
}

logs() {
    podman logs -f "$CONTAINER_NAME"
}

shell() {
    podman exec -it "$CONTAINER_NAME" /bin/sh
}

status() {
    if podman ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "MPD container is running"
        MPD_HOST=127.0.0.1 mpc status 2>/dev/null || echo "(mpc not available or cannot connect)"
    else
        echo "MPD container is not running"
    fi
}

case "${1:-run}" in
    build)  build ;;
    run)    run ;;
    stop)   stop ;;
    logs)   logs ;;
    shell)  shell ;;
    status) status ;;
    restart) stop; sleep 1; run ;;
    *)
        echo "Usage: $0 [build|run|stop|logs|shell|status|restart]"
        exit 1
        ;;
esac
