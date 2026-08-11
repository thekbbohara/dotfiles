#!/usr/bin/env bash
# install.sh - bootstrap this dotfiles repo.
#
# Tested on Arch Linux. Requires sudo for package installation.
# Usage: curl -fsSL .../install.sh | bash   (or)   ./install.sh [--yes]
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/kb/dotfiles}"
AUR_HELPER=""
YES_FLAG=""

# --- helper -------------------------------------------------------------

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m::\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; exit 1; }

[[ $# -gt 0 && "$1" == "--yes" ]] && YES_FLAG="--noconfirm"

check_cmd() { command -v "$1" >/dev/null 2>&1; }

# --- distro detection ---------------------------------------------------

DISTRO="unknown"
PKG_MGR=""
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "$ID" in
        arch|endeavouros|artix)
            DISTRO="arch"
            PKG_MGR="pacman"
            ;;
        fedora)
            DISTRO="fedora"
            PKG_MGR="dnf"
            ;;
        ubuntu|debian)
            DISTRO="debian"
            PKG_MGR="apt"
            ;;
    esac
fi

info "detected distro: $DISTRO ($ID)"

# --- sudo up front ------------------------------------------------------

if [[ $PKG_MGR == "pacman" ]]; then
    sudo -v 2>/dev/null || sudo true
fi

# --- arch packages ------------------------------------------------------

PACMAN_PACKAGES=(
    stow git zsh
    hyprland hyprpaper hypridle hyprlock xdg-desktop-portal-hyprland
    waybar wofi swaync
    wezterm kitty dolphin
    tmux
    fzf ripgrep fd python-pillow wl-clipboard
    brightnessctl playerctl wireplumber
    ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-nerd-fonts-symbols
    python-pywal
    google-chrome
    # sesh            # tmux session manager (AUR)
    # clipse          # clipboard manager (AUR)
    # herdr           # tmux-flavoured terminal multiplexer (AUR)
    # quicksettings   # hypr quick settings panel (AUR)
)

# Packages that must come from the AUR.
AUR_PACKAGES=(
    # sesh
    # clipse
    # herdr
    # quicksettings
)

install_arch() {
    info "updating package database"
    sudo pacman -Sy $YES_FLAG

    missing=()
    for p in "${PACMAN_PACKAGES[@]}"; do
        pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        info "installing: ${missing[*]}"
        sudo pacman -S $YES_FLAG --needed "${missing[@]}"
    else
        info "all core packages already installed"
    fi

    if [[ ${#AUR_PACKAGES[@]} -gt 0 ]]; then
        if check_cmd yay; then AUR_HELPER="yay"; fi
        if check_cmd paru; then AUR_HELPER="paru"; fi
        [[ -n "$AUR_HELPER" ]] || die "AUR packages requested but neither yay nor paru is installed"

        missing=()
        for p in "${AUR_PACKAGES[@]}"; do
            pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p")
        done
        if [[ ${#missing[@]} -gt 0 ]]; then
            info "installing from AUR: ${missing[*]}"
            "$AUR_HELPER" -S $YES_FLAG --needed "${missing[@]}"
        fi
    fi
}

# --- non-arch fallbacks -------------------------------------------------

install_other() {
    warn "no package installation for $DISTRO yet; install manually:"
    warn "  stow git zsh tmux fzf ripgrep fd wl-clipboard hyprland hyprpaper"
    warn "  waybar wofi swaync wezterm kitty dolphin brightnessctl playerctl"
    warn "  pywal + nerd fonts"
}

# --- stow the dotfiles --------------------------------------------------

install_stow() {
    [[ -d "$DOTFILES" ]] || die "dotfiles dir not found: $DOTFILES"
    cd "$DOTFILES"

    info "stowing dotfiles into \$HOME"
    stow --target="$HOME" .
}

# --- oh-my-zsh + plugins + powerlevel10k --------------------------------

install_zsh() {
    local omz="$HOME/.oh-my-zsh"

    if [[ ! -d "$omz" ]]; then
        info "installing oh-my-zsh"
        ZSH="$omz" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
    fi

    mkdir -p "${ZSH_CUSTOM:-$omz/custom}/plugins" "${ZSH_CUSTOM:-$omz/custom}/themes"

    if [[ ! -d "${ZSH_CUSTOM:-$omz/custom}/themes/powerlevel10k" ]]; then
        info "installing powerlevel10k"
        git clone --depth=1 https://github.com/romkatv/powerlevel10k \
            "${ZSH_CUSTOM:-$omz/custom}/themes/powerlevel10k"
    fi

    for plug in zsh-autosuggestions zsh-syntax-highlighting; do
        if [[ ! -d "${ZSH_CUSTOM:-$omz/custom}/plugins/$plug" ]]; then
            info "installing zsh plugin: $plug"
            git clone --depth=1 "https://github.com/zsh-users/$plug" \
                "${ZSH_CUSTOM:-$omz/custom}/plugins/$plug"
        fi
    done
}

# --- tmux: tpm + plugins ------------------------------------------------

install_tmux() {
    local tpm="$HOME/.config/tmux/plugins/tpm"
    if [[ ! -d "$tpm" ]]; then
        info "installing tmux plugin manager (tpm)"
        mkdir -p "$(dirname "$tpm")"
        git clone --depth=1 https://github.com/tmux-plugins/tpm "$tpm"
    fi
    info "installing tmux plugins (first launch via tmux prefix+I required too)"
    "$tpm/bin/install_plugins" >/dev/null 2>&1 || true
}

# --- wallpaper dir ------------------------------------------------------

install_wallpapers() {
    mkdir -p "$HOME/wallpapers"
}

# --- main ---------------------------------------------------------------

case "$PKG_MGR" in
    pacman) install_arch ;;
    *)      install_other ;;
esac

install_stow
install_zsh
install_tmux
install_wallpapers

info "done."
cat <<'EOF'

  Next steps:
    1. Log out and back in (or start Hyprland) to pick up the new shell.
    2. First tmux session:  tmux new -s main   then press  Ctrl-Space + I
       to finish installing tmux plugins.
    3. Drop wallpapers into ~/wallpapers, then use Super+W to cycle.
    4. Some tools live in the AUR (sesh, clipse, herdr, quicksettings):
       install them with your AUR helper and uncomment the lines in install.sh.
EOF
