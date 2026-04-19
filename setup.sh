#!/usr/bin/env bash
set -euo pipefail

# ── Config ──────────────────────────���───────────────────────────────
BOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_NAME="printer-bot"
VENV_DIR="$BOT_DIR/venv"

echo "=== Printer Bot Setup (Ubuntu Server) ==="
echo "Install directory: $BOT_DIR"
echo ""

# ── Detect install vs update ──────────────────────────────────────
if [ -d "$VENV_DIR" ] && [ -f "$BOT_DIR/.env" ]; then
    MODE="update"
    echo "Existing installation detected. Running in UPDATE mode."
else
    MODE="install"
    echo "Fresh installation."
fi
echo ""

# ── Auto-update from git ─────────────────────────────────────────
if [ -d "$BOT_DIR/.git" ]; then
    echo "Checking for updates..."
    cd "$BOT_DIR"
    git fetch origin 2>/dev/null || true
    LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "none")
    REMOTE=$(git rev-parse origin/main 2>/dev/null || echo "none")
    if [ "$LOCAL" != "$REMOTE" ] && [ "$REMOTE" != "none" ]; then
        echo "New version available. Pulling updates..."
        git pull origin main
        echo "Updated to latest version."
        echo ""
        # Re-exec setup.sh in case it changed
        exec "$BOT_DIR/setup.sh" "$@"
    else
        echo "Already up to date."
    fi
    echo ""
fi

# ── 1. System packages ─────────────────────────��───────────────────
echo "[1/7] Installing system packages..."
sudo apt update
sudo apt install -y \
    cups libcups2-dev \
    hplip \
    libreoffice-core libreoffice-writer libreoffice-impress \
    poppler-utils \
    python3 python3-pip python3-venv python3-dev \
    gcc

# ── 2. CUPS ─────────────────────────────────────────���──────────────
echo "[2/7] Configuring CUPS..."
sudo systemctl enable --now cups
sudo usermod -aG lpadmin "$USER"

# ── 3. Printer setup ──���──────────────────────���────────────────────
if [ "$MODE" = "update" ]; then
    echo "[3/7] Skipping printer setup (already configured)."
else
    echo "[3/7] Setting up HP Smart Tank 725..."
    echo ""

    if lpstat -p 2>/dev/null | grep -qi "hp"; then
        echo "HP printer already detected in CUPS:"
        lpstat -p
        echo ""
        read -rp "Skip printer setup? (Y/n): " SKIP_PRINTER
        SKIP_PRINTER="${SKIP_PRINTER:-Y}"
    else
        SKIP_PRINTER="n"
    fi

    if [[ "${SKIP_PRINTER,,}" != "y" ]]; then
        echo "Connect the HP Smart Tank 725 via USB now, then press Enter."
        read -r
        sudo hp-setup -i
        echo ""
        echo "Printer configured. Verifying..."
        lpstat -p
    fi
fi

# Get printer name
DETECTED_PRINTER=$(lpstat -p 2>/dev/null | head -1 | awk '{print $2}' || true)
if [ -z "$DETECTED_PRINTER" ]; then
    DETECTED_PRINTER="HP_Smart_Tank_725"
fi

# ── 4. Python virtual environment ─────────��───────────────────────
if [ -d "$VENV_DIR" ]; then
    echo "[4/7] Updating Python packages..."
    "$VENV_DIR/bin/pip" install --upgrade pip
    "$VENV_DIR/bin/pip" install -r "$BOT_DIR/requirements.txt" --upgrade
else
    echo "[4/7] Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install --upgrade pip
    "$VENV_DIR/bin/pip" install -r "$BOT_DIR/requirements.txt"
fi

# ── 5. Configure .env ───────────────────���─────────────────────────
echo "[5/7] Configuring bot..."

if [ -f "$BOT_DIR/.env" ]; then
    echo ".env already exists. Checking for new variables..."

    # Check for GEMINI_API_KEY (added in v2 — voice notes)
    if ! grep -q "GEMINI_API_KEY" "$BOT_DIR/.env"; then
        echo ""
        echo "New feature: Voice notes via Google Gemini AI"
        echo "Get a free API key at: https://aistudio.google.com/apikey"
        read -rp "Gemini API key (press Enter to skip): " GEMINI_KEY
        if [ -n "$GEMINI_KEY" ]; then
            echo "GEMINI_API_KEY=$GEMINI_KEY" >> "$BOT_DIR/.env"
            echo "Gemini API key added."
        else
            echo "Skipped. Voice notes will be disabled."
        fi
    fi
else
    echo ""
    read -rp "Telegram bot token (from @BotFather): " BOT_TOKEN
    read -rp "Your Telegram user ID (from @userinfobot): " USER_IDS
    echo ""
    echo "Optional: Voice notes via Google Gemini AI"
    echo "Get a free API key at: https://aistudio.google.com/apikey"
    read -rp "Gemini API key (press Enter to skip): " GEMINI_KEY

    {
        echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN"
        echo "ALLOWED_USER_IDS=$USER_IDS"
        echo "PRINTER_NAME=$DETECTED_PRINTER"
        if [ -n "$GEMINI_KEY" ]; then
            echo "GEMINI_API_KEY=$GEMINI_KEY"
        fi
    } > "$BOT_DIR/.env"

    chmod 600 "$BOT_DIR/.env"
    echo ".env created."
fi

# ── 6. Create temp directory ──────────────────────────────────────
echo "[6/7] Creating temp directory..."
mkdir -p /tmp/printer_bot

# ── 7. Systemd service ────────────────���──────────────────────────
echo "[7/7] Configuring systemd service..."

sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<SERVICEEOF
[Unit]
Description=Telegram Printer Bot
After=network-online.target cups.service
Wants=network-online.target cups.service

[Service]
Type=simple
User=$USER
Group=$(id -gn)
WorkingDirectory=$BOT_DIR
ExecStart=$VENV_DIR/bin/python3 $BOT_DIR/bot.py
Restart=always
RestartSec=5
EnvironmentFile=$BOT_DIR/.env

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/tmp/printer_bot $BOT_DIR
PrivateTmp=false

[Install]
WantedBy=multi-user.target
SERVICEEOF

sudo systemctl daemon-reload

if systemctl is-active --quiet "$SERVICE_NAME"; then
    sudo systemctl restart "$SERVICE_NAME"
    echo "Service restarted with new code."
else
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl start "$SERVICE_NAME"
    echo "Service installed and started."
fi

echo ""
echo "=== Setup complete! ==="
echo ""
if [ "$MODE" = "update" ]; then
    echo "Bot has been updated and restarted."
else
    echo "The bot is running and will start automatically on boot."
    echo ""
    echo "If you skipped the Gemini API key, you can add it later:"
    echo "  echo 'GEMINI_API_KEY=your-key' >> $BOT_DIR/.env"
    echo "  sudo systemctl restart $SERVICE_NAME"
fi
echo ""
echo "Useful commands:"
echo "  Status:   sudo systemctl status $SERVICE_NAME"
echo "  Logs:     sudo journalctl -u $SERVICE_NAME -f"
echo "  Restart:  sudo systemctl restart $SERVICE_NAME"
echo "  Stop:     sudo systemctl stop $SERVICE_NAME"
echo ""
echo "To update the bot later:"
echo "  cd $BOT_DIR"
echo "  git pull"
echo "  sudo ./setup.sh"
