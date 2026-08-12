#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="$HOME/wallpapers"
TARGET="$HOME/.config/hypr/wallpaper.png"
LOCK="/tmp/wallpaper-loop.pid"
WAL_PY="$HOME/.local/venvs/wal/bin/python3"
WAL_BIN="${WAL_BIN:-$HOME/.local/bin/wal}"

change() {
    # Video wallpaper active (mpvpaper) - don't touch hyprpaper, would cover the video.
    if pgrep -x mpvpaper > /dev/null 2>&1; then
        return 0
    fi
    local wall="${1:-}"
    if [[ -z "$wall" ]]; then
        wall="$(find "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | shuf -n 1)"
    fi
    [[ -n "$wall" ]] || { echo "no wallpapers found in $WALL_DIR" >&2; return 1; }
    if [[ "${wall,,}" != *.png ]]; then
        "$WAL_PY" -c "from PIL import Image; Image.open('$wall').convert('RGB').save('$TARGET', 'PNG')" 2>/dev/null || cp "$wall" "$TARGET"
    else
        cp "$wall" "$TARGET"
    fi
    "$WAL_BIN" -i "$TARGET" --backend fast_colorthief8 -a 85 -q -n >/dev/null 2>&1 || true
    # Touch the WezTerm config so running terminals reload their palette.
    touch "$HOME/.config/wezterm/wezterm.lua" 2>/dev/null || true
    cp "$HOME/.cache/wal/style.css" "$HOME/.config/waybar/style.css" 2>/dev/null || true
    cp "$HOME/.cache/wal/wofi-style.css" "$HOME/.config/wofi/style.css" 2>/dev/null || true
    cp "$HOME/.cache/wal/swaync-style.css" "$HOME/.config/swaync/style.css" 2>/dev/null || true
    # Update wallpaper via hyprpaper IPC - no kill/restart, no flicker.
    # If hyprpaper is not running (first boot race), start it and wait briefly.
    if ! pgrep -x hyprpaper >/dev/null 2>&1; then
        hyprpaper >/dev/null 2>&1 &
        sleep 0.5
    fi
    hyprctl hyprpaper wallpaper "eDP-1,$TARGET,cover" >/dev/null 2>&1 || true
    # Reload waybar/swaync for new colours - no hyprctl reload (avoids window retiling).
    pkill -SIGUSR2 waybar >/dev/null 2>&1 || { pkill waybar >/dev/null 2>&1 || true; waybar >/dev/null 2>&1 & }
    pkill swaync >/dev/null 2>&1 || true
    swaync >/dev/null 2>&1 &
}

if [[ "${1:-}" == "--once" ]]; then
    change "${2:-}"
    exit 0
fi

[[ -f "$LOCK" ]] && kill "$(cat "$LOCK")" 2>/dev/null
echo $$ > "$LOCK"
trap '[[ -f "$LOCK" ]] && [[ "$(cat "$LOCK" 2>/dev/null)" == "$$" ]] && rm -f "$LOCK"' EXIT

while true; do
    change
    sleep 60
done
