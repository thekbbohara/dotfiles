#!/usr/bin/env bash
# Open the browser, or focus it if already running.
# If the browser was fullscreen, its fullscreen state is remembered and
# restored (Hyprland drops a window's fullscreen when another window on the
# same workspace is focused).

browser="google-chrome-stable"
class="google-chrome"
state_file="${XDG_CACHE_HOME:-$HOME/.cache}/open-browser-chrome-fs"

active_class=$(hyprctl activewindow -j 2>/dev/null | grep -o '"class": *"[^"]*"' | sed 's/.*: *"//;s/"//')
if [ "${active_class}" = "${class}" ]; then
    hyprctl activewindow -j 2>/dev/null | grep -o '"fullscreen": *[0-9]' | grep -o '[0-9]' > "${state_file}"
    exit 0
fi

fs_state=0
[ -f "${state_file}" ] && fs_state=$(cat "${state_file}")

target=$(hyprctl clients -j 2>/dev/null | python3 -c '
import json, sys

class_name, fs_state = sys.argv[1], sys.argv[2]
try:
    clients = json.load(sys.stdin)
except Exception:
    clients = []

same = [c for c in clients if c.get("class") == class_name]
if not same:
    print("__LAUNCH__")
    sys.exit(0)

for c in same:
    if c.get("fullscreen"):
        print("KEEP:" + c["address"])
        sys.exit(0)
if fs_state and fs_state != "0":
    print("RESTORE:" + same[0]["address"])
else:
    print(same[0]["address"])
' "${class}" "${fs_state}")

focus_window() {
    local addr="$1"
    hyprctl dispatch "hl.dsp.focus({ window = \"address:${addr}\" })"
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        local cur
        cur=$(hyprctl activewindow -j 2>/dev/null | grep -o '"address": *"[^"]*"' | sed 's/.*: *"//;s/"//')
        [ "${cur}" = "${addr}" ] && return 0
        sleep 0.1
    done
    return 1
}

case "${target}" in
    __LAUNCH__)
        echo 0 > "${state_file}"
        "${browser}" >/dev/null 2>&1 &
        disown
        ;;
    KEEP:*)
        focus_window "${target#KEEP:}"
        ;;
    RESTORE:*)
        addr="${target#RESTORE:}"
        if focus_window "${addr}"; then
            mode="maximized"
            [ "${fs_state}" = "2" ] && mode="fullscreen"
            hyprctl dispatch "hl.dsp.window.fullscreen({ action = \"set\", mode = \"${mode}\" })"
            echo "${fs_state}" > "${state_file}"
        fi
        ;;
    *)
        focus_window "${target}"
        ;;
esac
