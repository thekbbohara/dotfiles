#!/usr/bin/env bash
# Toggle between video wallpaper (mpvpaper) and picture wallpaper (hyprpaper).
# Video mode uses mpvpaper slideshow (-n) so videos rotate inside one mpv
# process - no kill/restart gap, no flash of the default Hyprland background.

VID_DIR="$HOME/vidpapers"
PLIST="/tmp/vidpapers.m3u"
LOG="/tmp/wallpaper-toggle.log"
SOCK="/tmp/mpvpaper-eDP-1.sock"
ROTATE_SECS="${ROTATE_SECS:-60}"

state() {
    if pgrep -x mpvpaper > /dev/null 2>&1; then
        echo "video"
    else
        echo "pic"
    fi
}

log() { echo "$(date '+%H:%M:%S') - $*" >> "$LOG"; }

video_on() {
    mapfile -t videos < <(find "$VID_DIR" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.webm' \) 2>/dev/null)
    (( ${#videos[@]} > 0 )) || { log "no videos found in $VID_DIR"; return 1; }
    printf '%s\n' "${videos[@]}" > "$PLIST"
    pkill -x hyprpaper 2>/dev/null
    pkill -x mpvpaper 2>/dev/null
    sleep 0.5
    env LIBVA_DRIVER_NAME=nvidia GBM_BACKEND=nvidia-drm \
        mpvpaper -n "$ROTATE_SECS" \
        -o "input-ipc-server=$SOCK --shuffle --no-audio --vo=gpu-next --hwdec=auto --vd-lavc-software-fallback=no --playlist=$PLIST" \
        eDP-1 >> /tmp/mpvpaper.log 2>&1 &
    log "video on (slideshow every ${ROTATE_SECS}s, ${#videos[@]} videos)"
}

video_off() {
    pkill -x mpvpaper 2>/dev/null
    sleep 0.5
    if ! pgrep -x hyprpaper > /dev/null 2>&1; then
        hyprpaper > /dev/null 2>&1 &
        sleep 0.5
    fi
    hyprctl hyprpaper wallpaper "eDP-1,$HOME/.config/hypr/wallpaper.png,cover" > /dev/null 2>&1 || true
    log "video off, pic on"
}

video_next() {
    # Ask running mpv to jump to the next playlist entry (no restart, no flash).
    python3 - <<'EOF'
import socket, sys
sock = "/tmp/mpvpaper-eDP-1.sock"
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(2)
    s.connect(sock)
    s.sendall(b'{"command": ["playlist-next"]}\n')
    s.close()
except Exception as e:
    sys.stderr.write(f"next failed: {e}\n")
    sys.exit(1)
EOF
    log "next requested"
}

case "${1:-state}" in
    toggle)
        if [[ "$(state)" == "video" ]]; then video_off; else video_on; fi
        ;;
    next)
        video_next
        ;;
    on)
        video_on
        ;;
    off)
        video_off
        ;;
    state)
        state
        ;;
    *)
        echo "usage: $0 {toggle|next|on|off|state}" >&2
        exit 1
        ;;
esac
