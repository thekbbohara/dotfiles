#!/usr/bin/env bash
# keys-menu.sh - clipse-style TUI for ~/.secrets/keys.
# Format: entries are name\nkey pairs separated by lines of dashes.
# Keys: j/k or arrows navigate, type to filter, enter/click copies + closes,
#       ctrl-a adds a new entry, ctrl-e edits the selected entry.

set -uo pipefail

KEYS_FILE="${KEYS_FILE:-${HOME}/.secrets/keys}"
BIN="$(readlink -f "${BASH_SOURCE[0]}")"
EDITOR_CMD="${VISUAL:-${EDITOR:-nvim}}"

labels=()
payloads=()

read_keys() {
	labels=()
	payloads=()
	[[ -s "$KEYS_FILE" ]] || return 1
	local label=""
	local line
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		[[ "$line" == \#* ]] && continue
		if [[ "$line" =~ ^[-[:space:]]+$ ]]; then
			label=""
			continue
		fi
		if [[ -n "$label" ]]; then
			labels+=("$label")
			payloads+=("$line")
			label=""
		else
			label="$line"
		fi
	done < "$KEYS_FILE"
}

uniquify() {
	local -n arr="$1"
	local count=0
	declare -A seen
	local i l
	for i in "${!arr[@]}"; do
		l="${arr[$i]}"
		if [[ -n "${seen[$l]:-}" ]]; then
			count=$((count + 1))
			arr[$i]="${l}  · ${count}"
		else
			seen[$l]=1
		fi
	done
}

list_names() {
	read_keys || exit 1
	uniquify labels
	printf '%s\n' "${labels[@]}"
}

add_entry() {
	read_keys || true
	local tmp
	tmp="$(mktemp)"
	printf '# name\n# key\n' > "$tmp"
	"$EDITOR_CMD" "$tmp"
	local -a lines
	mapfile -t lines < <(awk 'NF && $0 !~ /^#/ {print}' "$tmp")
	rm -f "$tmp"
	(( ${#lines[@]} >= 2 )) || return 1
	local out
	out="$(mktemp)"
	if tail -n 1 "$KEYS_FILE" 2>/dev/null | grep -qE '^[-[:space:]]+$'; then
		head -n -1 "$KEYS_FILE" > "$out"
	else
		cp "$KEYS_FILE" "$out"
	fi
	printf -- '-\n%s\n%s\n' "${lines[0]}" "${lines[1]}" >> "$out"
	mv "$out" "$KEYS_FILE"
	chmod 600 "$KEYS_FILE" 2>/dev/null || true
}

edit_entry() {
	local target="$1"
	read_keys || return 1
	local name_line key_line newtmp new_name new_key
	name_line="$(grep -n -F -x -- "$target" "$KEYS_FILE" | head -n 1 | cut -d: -f1)"
	[[ -n "$name_line" ]] || return 1
	key_line="$(awk -v s=$((name_line + 1)) 'NR>=s && NF && $0 !~ /^#/ && $0 !~ /^[-[:space:]]+$/ {print NR; exit}' "$KEYS_FILE")"
	[[ -n "$key_line" ]] || return 1
	newtmp="$(mktemp)"
	{
		sed -n "${name_line}p" "$KEYS_FILE"
		sed -n "${key_line}p" "$KEYS_FILE"
	} > "$newtmp"
	"$EDITOR_CMD" "$newtmp"
	new_name="$(sed -n '1p' "$newtmp")"
	new_key="$(sed -n '2p' "$newtmp")"
	rm -f "$newtmp"
	[[ -n "$new_name" && -n "$new_key" ]] || return 1
	local out
	out="$(mktemp)"
	awk -v nl="$name_line" -v kl="$key_line" -v nn="$new_name" -v nk="$new_key" '
		NR == nl { print nn; next }
		NR == kl { print nk; next }
		{ print }
	' "$KEYS_FILE" > "$out"
	mv "$out" "$KEYS_FILE"
	chmod 600 "$KEYS_FILE" 2>/dev/null || true
}

copy_key() {
	local target="$1"
	read_keys || return 1
	local i idx=0
	for i in "${!labels[@]}"; do
		if [[ "${labels[$i]}" == "$target" ]]; then
			idx=$((i + 1))
			break
		fi
	done
	(( idx > 0 )) || return 1
	printf '%s' "${payloads[$((idx - 1))]}" | wl-copy >/dev/null 2>&1
	command -v notify-send >/dev/null 2>&1 && notify-send -a keys-menu "copied ${target}"
	return 0
}

case "${1:-}" in
	--list)
		list_names
		exit 0
		;;
	--add)
		add_entry
		exit $?
		;;
	--edit)
		edit_entry "${2:-}"
		exit $?
		;;
esac

list_names >/dev/null || {
	command -v notify-send >/dev/null 2>&1 && notify-send -a keys-menu "no keys file at ${KEYS_FILE}"
	exit 1
}

bind="left-click:accept,ctrl-a:execute($BIN --add)+reload($BIN --list),ctrl-e:execute($BIN --edit {})+reload($BIN --list)"

sel="$(printf '%s\n' "${labels[@]}" | fzf \
	--height=100% \
	--border=rounded \
	--border-label=' keys ' \
	--prompt='filter > ' \
	--no-info \
	--bind="$bind" \
	--color='fg:#ffffff,fg+:#ff69b4,pointer:#ff69b4,hl+:#ff69b4,hl:#ff69b4,prompt:#2ecc71,border:#3498db,label:#6f4cbc')"

[[ -n "$sel" ]] || exit 130
copy_key "$sel"
