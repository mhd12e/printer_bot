#!/usr/bin/env bash
set -euo pipefail

# PrintBot one-liner installer
# Usage: sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/mhd12e/printbot/main/install.sh)"

REPO="https://github.com/mhd12e/printbot.git"
INSTALL_DIR="$HOME/printbot"

if [ -n "${SUDO_USER:-}" ]; then
    INSTALL_DIR="$(eval echo "~$SUDO_USER")/printbot"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

CLONED_FRESH=false

_rollback() {
    echo ""
    echo -e "${RED}${BOLD}Installation failed. Rolling back...${NC}"
    if [ "$CLONED_FRESH" = true ] && [ -d "$INSTALL_DIR" ]; then
        echo "  Removing $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
        echo "  Cleaned up."
    fi
    echo ""
    echo "  Fix the issue and try again."
    exit 1
}

trap _rollback ERR

echo -e "${BOLD}PrintBot Installer${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Run with sudo:${NC}"
    echo '  sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/mhd12e/printbot/main/install.sh)"'
    exit 1
fi

# Install git if missing
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    apt update -qq && apt install -y -qq git > /dev/null
fi

# Clone or update
if [ -d "$INSTALL_DIR/.git" ]; then
    echo "PrintBot already cloned at $INSTALL_DIR. Pulling latest..."
    git -C "$INSTALL_DIR" pull origin main
else
    echo "Cloning PrintBot to $INSTALL_DIR..."
    git clone "$REPO" "$INSTALL_DIR"
    chown -R "$SUDO_USER:$(id -gn "$SUDO_USER")" "$INSTALL_DIR"
    CLONED_FRESH=true
fi

echo ""

# Disable our trap — printbot install has its own rollback
trap - ERR

chmod +x "$INSTALL_DIR/printbot"
exec "$INSTALL_DIR/printbot" install
