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
sudo ./printbot install
```

That's it. The installer handles everything: system packages, CUPS, printer drivers, Python venv, config prompts, systemd service, and adds `printbot` to your PATH.

After install, open your bot on Telegram and send `/start`.

## Managing the Bot

```bash
printbot status           # Check bot status, version, printer info
printbot logs -f          # Follow live logs
printbot logs 100         # Last 100 log lines
sudo printbot restart     # Restart the bot
sudo printbot stop        # Stop the bot
sudo printbot start       # Start the bot
```

## Updating

```bash
sudo printbot update
```

Pulls latest code from git, updates Python packages, runs migrations (prompts for new config if needed), and restarts the service.

## Configuration

```bash
printbot config               # Show config (secrets masked)
sudo printbot config edit     # Open .env in editor
sudo printbot config set KEY=VALUE  # Set a single value
```

Config lives in `.env`:

```env
TELEGRAM_BOT_TOKEN=your-bot-token
ALLOWED_USER_IDS=123456789,987654321
PRINTER_NAME=HP_Smart_Tank_725
GEMINI_API_KEY=your-gemini-key  # optional, for voice notes
```

## Printer

```bash
printbot printer          # Show printer status and queue
sudo printbot printer setup   # Run HP printer setup wizard
```

## Uninstall

```bash
sudo printbot uninstall   # Removes service and venv, keeps .env and code
```

## All Commands

```
printbot install          First-time setup
printbot update           Pull, update deps, migrate, restart
printbot uninstall        Remove service and venv
printbot start/stop/restart   Service control
printbot status           Status, version, printer info
printbot logs [-f] [N]    View logs
printbot config [show|edit|set]   Manage .env
printbot printer [setup]  Printer info or setup wizard
printbot migrate          Run pending migrations
printbot version          Show version
printbot help             Show all commands
```

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
