#!/usr/bin/env bash
# =============================================================================
# apply-theme.sh — Sub Theme (Gotland Navy) Installer for macOS
# Ported from https://github.com/sgt-nylle/omarchy-sub-theme
# Swedish Navy (Kungliga Flottan) · HSwMS Gotland (A19) · Cold War Bluedark
#
# Native, idempotent, zero-SIP-modification setup:
#   1. Switches macOS System Appearance to Dark Mode via AppleScript.
#   2. Sets macOS Accent Color & Highlight Color (#164682 / #38BDF8) via defaults.
#   3. Sets the selected 2736x1824 Gotland-class wallpaper across all connected
#      displays/spaces via System Events AppleScript.
#   4. Imports Sub-Theme.itermcolors into iTerm2 and installs theme files for
#      Ghostty, Kitty, and Alacritty when detected.
# =============================================================================

set -euo pipefail

# ── ANSI Colors matching omarchy-sub-theme/colors.toml ──────────────────────
CYAN="\033[38;2;56;189;248m"      # #38bdf8 (Periscope Cyan)
GOLD="\033[38;2;254;204;2m"       # #fecc02 (Swedish Naval Gold)
GREEN="\033[38;2;52;211;153m"     # #34d399 (Sonar Contact Green)
RED="\033[38;2;255;92;92m"        # #ff5c5c (Red Alert)
MUTED="\033[38;2;91;130;184m"     # #5b82b8 (Steel-Navy Muted)
FG="\033[38;2;226;238;255m"       # #e2eeff (Readout White-Blue)
RESET="\033[0m"

log_info()  { printf "${CYAN}⚓ [Sub Theme]${RESET} ${FG}%s${RESET}\n" "$*"; }
log_ok()    { printf "   ${GREEN}✔${RESET} ${FG}%s${RESET}\n" "$*"; }
log_warn()  { printf "   ${GOLD}⚠${RESET} ${MUTED}%s${RESET}\n" "$*"; }
log_err()   { printf "   ${RED}✖ %s${RESET}\n" "$*" >&2; }

WALLPAPER_INDEX=1
REVERT=0

usage() {
  cat <<EOF
Usage: ./apply-theme.sh [options]

Options:
  -w, --wallpaper <1-4>   Select Gotland-class Cold War bluedark wallpaper (default: 1)
                            1 = 01-stockholm-archipelago-night-patrol.png (Default)
                            2 = 02-hms-gotland-tactical-blueprint.png
                            3 = 03-baltic-sonar-silent-running.png
                            4 = 04-dawn-torpedo-run.png
  -r, --revert            Revert macOS accent/highlight colors to system defaults
  -h, --help              Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--wallpaper)
      WALLPAPER_INDEX="${2:-1}"
      shift 2
      ;;
    -r|--revert)
      REVERT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_err "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

# ── 0. OS & Permission Checks ───────────────────────────────────────────────
if [[ "$(uname -s)" != "Darwin" ]]; then
  log_err "This script is designed for macOS (Darwin). Detected: $(uname -s)"
  exit 1
fi

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  log_err "Please run ./apply-theme.sh as your normal macOS user (do NOT use sudo)."
  exit 1
fi

# Resolve repository directory (or clone to ~/.local/share/macos-sub-theme if piped via curl)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
if [[ ! -d "${SCRIPT_DIR}/backgrounds" ]]; then
  INSTALL_DIR="${HOME}/.local/share/macos-sub-theme"
  log_info "Downloading macos-sub-theme assets to ${INSTALL_DIR}..."
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    git -C "${INSTALL_DIR}" pull --ff-only
  else
    mkdir -p "$(dirname "${INSTALL_DIR}")"
    git clone https://github.com/sgt-nylle/macos-sub-theme.git "${INSTALL_DIR}"
  fi
  SCRIPT_DIR="${INSTALL_DIR}"
fi

# ── Revert Mode ─────────────────────────────────────────────────────────────
if [[ "${REVERT}" -eq 1 ]]; then
  log_info "Reverting macOS Accent & Highlight colors to system defaults..."
  defaults delete -g AppleAccentColor 2>/dev/null || true
  defaults delete -g AppleHighlightColor 2>/dev/null || true
  defaults delete -g AppleInterfaceStyleSwitchesAutomatically 2>/dev/null || true
  log_ok "macOS NSGlobalDomain accent & highlight keys reset to Multicolor default."
  exit 0
fi

# ── 1. Enable macOS Dark Mode via AppleScript ───────────────────────────────
log_info "Switching macOS Appearance to Dark Mode..."
defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool false 2>/dev/null || true
if osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' 2>/dev/null; then
  log_ok "macOS System Appearance set to Dark Mode."
else
  log_warn "Could not toggle Dark Mode via System Events (check System Settings → Privacy & Security → Automation)."
fi

# ── 2. Configure macOS Accent & Selection Highlight Colors ──────────────────
# AppleAccentColor integer codes:
#   4 = Blue | -1 = Graphite | 5 = Purple | 6 = Pink | 0 = Red | 1 = Orange | 2 = Yellow | 3 = Green
# AppleHighlightColor normalized sRGB string:
#   #164682 (Tactical Navy Selection): R=22/255 (0.086275), G=70/255 (0.274510), B=130/255 (0.509804)
log_info "Applying Gotland Navy & Periscope Cyan highlight colors (defaults write -g)..."
defaults write -g AppleAccentColor -int 4
defaults write -g AppleHighlightColor -string "0.086275 0.274510 0.509804 Blue"
log_ok "AppleAccentColor=4 (Navy/Blue) | AppleHighlightColor='#164682' (Tactical Navy Selection)."

# ── 3. Set Desktop Wallpaper Across All Connected Displays ──────────────────
case "${WALLPAPER_INDEX}" in
  1) WALLPAPER_FILE="01-stockholm-archipelago-night-patrol.png" ;;
  2) WALLPAPER_FILE="02-hms-gotland-tactical-blueprint.png" ;;
  3) WALLPAPER_FILE="03-baltic-sonar-silent-running.png" ;;
  4) WALLPAPER_FILE="04-dawn-torpedo-run.png" ;;
  *)
    log_err "Invalid wallpaper index '${WALLPAPER_INDEX}'. Choose 1, 2, 3, or 4."
    exit 1
    ;;
esac

WALLPAPER_PATH="${SCRIPT_DIR}/backgrounds/${WALLPAPER_FILE}"
if [[ ! -f "${WALLPAPER_PATH}" ]]; then
  log_err "Wallpaper file not found: ${WALLPAPER_PATH}"
  exit 1
fi

log_info "Setting wallpaper [${WALLPAPER_INDEX}/4] across all connected displays: ${WALLPAPER_FILE}..."
if osascript -e "tell application \"System Events\" to tell every desktop to set picture to POSIX file \"${WALLPAPER_PATH}\"" 2>/dev/null; then
  log_ok "Wallpaper applied to all active macOS desktops."
elif osascript -e "tell application \"Finder\" to set desktop picture to POSIX file \"${WALLPAPER_PATH}\"" 2>/dev/null; then
  log_ok "Wallpaper applied via Finder."
else
  log_warn "AppleScript wallpaper update requires Automation permission. Set manually from: ${WALLPAPER_PATH}"
fi

# ── 4. Configure Terminal Emulators (iTerm2, Ghostty, Kitty, Alacritty) ─────
log_info "Configuring installed macOS terminal emulators..."

# 4a. iTerm2 (.itermcolors preset import)
ITERM_COLORS="${SCRIPT_DIR}/Sub-Theme.itermcolors"
if [[ -d "/Applications/iTerm.app" || -d "${HOME}/Applications/iTerm.app" ]]; then
  open -g "${ITERM_COLORS}" 2>/dev/null || true
  log_ok "iTerm2 detected — imported Sub-Theme.itermcolors (select 'Sub-Theme' in Settings → Profiles → Colors)."
else
  log_ok "Sub-Theme.itermcolors ready at: ${ITERM_COLORS}"
fi

# 4b. Ghostty
if [[ -d "/Applications/Ghostty.app" || -d "${HOME}/.config/ghostty" ]] || command -v ghostty >/dev/null 2>&1; then
  mkdir -p "${HOME}/.config/ghostty/themes"
  cp "${SCRIPT_DIR}/configs/ghostty.conf" "${HOME}/.config/ghostty/themes/sub-theme"
  GHOSTTY_CFG="${HOME}/.config/ghostty/config"
  if [[ -f "${GHOSTTY_CFG}" ]]; then
    cp "${GHOSTTY_CFG}" "${GHOSTTY_CFG}.subtheme.bak"
    if grep -qE '^\s*theme\s*=' "${GHOSTTY_CFG}"; then
      sed -i '' 's|^[[:space:]]*theme[[:space:]]*=.*|theme = sub-theme|' "${GHOSTTY_CFG}"
    else
      printf "\n# Sub Theme (Gotland Navy)\ntheme = sub-theme\n" >> "${GHOSTTY_CFG}"
    fi
  else
    printf "# Sub Theme (Gotland Navy)\ntheme = sub-theme\n" > "${GHOSTTY_CFG}"
  fi
  log_ok "Ghostty configured: ~/.config/ghostty/themes/sub-theme (theme = sub-theme)."
fi

# 4c. Kitty
if [[ -d "/Applications/kitty.app" || -d "${HOME}/.config/kitty" ]] || command -v kitty >/dev/null 2>&1; then
  mkdir -p "${HOME}/.config/kitty"
  cp "${SCRIPT_DIR}/configs/kitty.conf" "${HOME}/.config/kitty/sub-theme.conf"
  KITTY_CFG="${HOME}/.config/kitty/kitty.conf"
  if [[ -f "${KITTY_CFG}" ]]; then
    if ! grep -q "sub-theme.conf" "${KITTY_CFG}"; then
      cp "${KITTY_CFG}" "${KITTY_CFG}.subtheme.bak"
      printf "\n# Sub Theme (Gotland Navy)\ninclude sub-theme.conf\n" >> "${KITTY_CFG}"
    fi
  else
    printf "# Sub Theme (Gotland Navy)\ninclude sub-theme.conf\n" > "${KITTY_CFG}"
  fi
  log_ok "Kitty configured: ~/.config/kitty/sub-theme.conf."
fi

# 4d. Alacritty
if [[ -d "/Applications/Alacritty.app" || -d "${HOME}/.config/alacritty" ]] || command -v alacritty >/dev/null 2>&1; then
  mkdir -p "${HOME}/.config/alacritty"
  cp "${SCRIPT_DIR}/configs/alacritty.toml" "${HOME}/.config/alacritty/sub-theme.toml"
  log_ok "Alacritty theme installed to ~/.config/alacritty/sub-theme.toml."
fi

printf "\n${CYAN}========================================================================${RESET}\n"
printf "  ${GOLD}⚓ Sub Theme (Gotland Navy) applied to macOS!${RESET}\n"
printf "  ${MUTED}• Switch wallpaper : ./apply-theme.sh --wallpaper 3  (1..4)${RESET}\n"
printf "  ${MUTED}• Revert defaults  : ./apply-theme.sh --revert${RESET}\n"
printf "${CYAN}========================================================================${RESET}\n"
