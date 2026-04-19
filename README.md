# PrinterBot

A Telegram bot that prints documents and images from your phone to a USB printer. Send a file, pick your settings with buttons, and it prints. That's it.

```
You (Telegram) --> Bot (Python) --> CUPS --> Printer (USB)
```

## What It Does

- Send a **PDF, DOCX, PPTX**, or any **image** to the bot on Telegram
- Pick print settings with **inline buttons** — no typing needed
- The bot prints it and gives you **live status updates**

### Print Options (all buttons)

| Option | Choices |
|---|---|
| Color | Color, B&W |
| Sides | One-sided, Long edge, Short edge |
| Orientation | Portrait, Landscape |
| Pages per sheet | 1, 2, 4, 6, 9 |
| Page range | All, Custom |
| Copies | - / + |

### Notifications

The bot tells you when:
- A job finishes or fails (with retry button)
- The printer goes offline or comes back
- Ink is running low

## Quick Start

### Prerequisites

- **Ubuntu Server** (tested on 24.04 LTS)
- **HP Smart Tank 725** connected via USB (other CUPS-compatible printers will work too)
- A **Telegram bot token** from [@BotFather](https://t.me/BotFather)
- Your **Telegram user ID** from [@userinfobot](https://t.me/userinfobot)

### Install

```bash
git clone https://github.com/mhd12e/printer_bot.git
cd printer_bot
chmod +x setup.sh
sudo ./setup.sh
```

The setup script handles everything:

1. Installs system packages (CUPS, HPLIP, LibreOffice, Python)
2. Configures CUPS and printer drivers
3. Walks you through printer setup (`hp-setup -i`)
4. Creates a Python virtual environment and installs dependencies
5. Prompts for your bot token and user ID
6. Installs a **systemd service** — the bot starts on boot and restarts on crash

After setup, the bot is running. Open it on Telegram and send `/start`.

## Managing the Bot

```bash
# Check status
sudo systemctl status printer-bot

# Watch live logs
sudo journalctl -u printer-bot -f

# Restart
sudo systemctl restart printer-bot

# Stop
sudo systemctl stop printer-bot
```

## Updating

```bash
cd printer_bot
git pull
sudo systemctl restart printer-bot
```

## Configuration

All config lives in `.env` (created by the setup script):

```env
TELEGRAM_BOT_TOKEN=your-bot-token
ALLOWED_USER_IDS=123456789,987654321
PRINTER_NAME=HP_Smart_Tank_725
```

- `ALLOWED_USER_IDS` — comma-separated Telegram user IDs that can use the bot
- `PRINTER_NAME` — must match `lpstat -p | awk '{print $2}'`

## How It Works

```
User sends file
      |
      v
  Download file
      |
      v
  DOCX/PPTX? --yes--> Convert to PDF (LibreOffice headless)
      |                        |
      no                       |
      |                        v
      +<-----------------------+
      |
      v
  Show settings screen (inline buttons)
      |
      v
  User taps [Print]
      |
      v
  Submit to CUPS with selected options
      |
      v
  Poll job status every 3s, update message
      |
      v
  Done / Failed (with retry) / Cancelled
```

## Project Structure

```
bot.py           Telegram handlers, conversation flow, background polling
printer.py       CUPS wrapper (submit, cancel, status, queue, ink levels)
converter.py     DOCX/PPTX to PDF conversion, page counting
config.py        Loads .env, defines constants and CUPS option mappings
setup.sh         One-command Ubuntu Server setup
requirements.txt Python dependencies
.env.example     Config template
```

## Supported Formats

| Type | Formats |
|---|---|
| Documents | PDF, DOCX, PPTX |
| Images | JPEG, PNG, GIF, BMP, TIFF, WEBP |

DOCX and PPTX are converted to PDF before printing. Images are sent directly to CUPS.

## Requirements

- **OS:** Ubuntu Server 24.04 LTS (recommended)
- **Printer:** Any CUPS-compatible printer via USB (tested with HP Smart Tank 725)
- **System packages:** CUPS, HPLIP, LibreOffice, poppler-utils
- **Python:** 3.10+
- **Python packages:** python-telegram-bot, pycups, Pillow, python-dotenv

## License

MIT
