# Printer Bot

A Telegram bot that receives documents and images, then prints them on a connected printer.

## Supported Formats

- **Documents:** PDF, DOCX, PPTX
- **Images:** JPEG, PNG, GIF, BMP, TIFF, WEBP

## Architecture

```
Telegram --> Bot (Python) --> CUPS (Linux printing system) --> Printer (USB)
```

- **Language:** Python
- **Telegram library:** python-telegram-bot
- **Printing backend:** CUPS via `pycups`
- **Document conversion:** LibreOffice headless (DOCX/PPTX to PDF)

## Core Flow

1. User sends a file or image to the bot via Telegram
2. Bot downloads the file
3. If DOCX/PPTX: convert to PDF using LibreOffice headless
4. Send the PDF/image to CUPS for printing
5. Reply to the user with print status (queued, printing, done, error)

## User Flow

Everything is buttons. No typing except /start and sending files.

### Starting the Bot
```
User:  /start
Bot:   Welcome to PrinterBot!
       Just send me a file or photo and I'll print it.

       Supported: PDF, DOCX, PPTX, JPG, PNG, GIF, BMP, TIFF, WEBP

       [ Printer Status ]   [ Print Queue ]
```

### Unauthorized User
```
User:  /start
Bot:   Sorry, you are not authorized to use this bot.
```

### Sending a File — Print Options Screen

When user sends any supported file, the bot shows a single settings screen.
All options are inline buttons. The currently selected option is marked with a checkmark.
Tapping a button toggles/cycles the value — the message updates in place.

```
User:  [sends report.pdf]

Bot:   report.pdf — 12 pages
       Ready to print. Choose your settings:

       Color:
       [ Color  ] [ B&W ]

       Sides:
       [ One-sided ] [ Long edge ] [ Short edge ]

       Orientation:
       [ Portrait ] [ Landscape ]

       Pages per sheet:
       [ 1 ] [ 2 ] [ 4 ] [ 6 ] [ 9 ]

       Page range:
       [ All ] [ Custom... ]

       Copies:
       [ - ]  1  [ + ]

       ────────────────────
       [ Print ]   [ Cancel ]
```

Notes:
- Default values: Color, One-sided, Portrait, 1 page/sheet, All pages, 1 copy
- Each button press updates the message in place (edit message, not new message)
- Selected options show as: [ * Color ] vs [ B&W ]
- "Custom..." for page range is the ONLY thing that asks for text input
  - Bot: "Type page range (e.g. 1-3, 5, 8-10):"
  - User types: "1-5"
  - Bot updates the settings screen with "Pages: 1-5"

### After Pressing Print — Live Status Updates
The same message keeps updating as the job progresses.
Bot polls CUPS job state and edits the message in place.

```
Bot:   [updates settings message to:]
       report.pdf — Job #42
       Color | One-sided | Portrait | 1/sheet | Pages 1-5 | 1 copy

       Status: Queued...
       [ Cancel Job ]

Bot:   [updates same message]
       report.pdf — Job #42
       Color | One-sided | Portrait | 1/sheet | Pages 1-5 | 1 copy

       Status: Printing... (page 2 of 5)
       [ Cancel Job ]

Bot:   [updates same message]
       report.pdf — Job #42
       Color | One-sided | Portrait | 1/sheet | Pages 1-5 | 1 copy

       Status: Done!
```

### Cancelling a Job
From the live status message:
```
User:  [taps "Cancel Job"]
Bot:   [updates same message]
       report.pdf — Job #42
       Cancelled.
```

From the print queue:
```
User:  [taps "Print Queue" on welcome screen]
Bot:   Print Queue:
       #42 — report.pdf — Printing...
       #43 — slides.pptx — Queued

       [ Cancel #42 ]  [ Cancel #43 ]  [ Cancel All ]

User:  [taps "Cancel #43"]
Bot:   [updates same message]
       Print Queue:
       #42 — report.pdf — Printing...

       [ Cancel #42 ]  [ Cancel All ]
```

### Notifications
Bot proactively notifies the user when something important happens,
even if they're not looking at the chat:

```
Bot:   Job #42 (report.pdf) finished printing.

Bot:   Job #43 (slides.pptx) failed: Paper jam. Clear the jam and tap Retry.
       [ Retry ]

Bot:   Printer went offline. Check USB connection.

Bot:   Printer is back online.

Bot:   Low paper warning.

Bot:   Low toner/ink warning.
```

### DOCX/PPTX Flow (conversion step)
```
User:  [sends slides.pptx]

Bot:   Converting slides.pptx to PDF...

Bot:   [updates same message]
       slides.pptx — 15 pages
       Ready to print. Choose your settings:

       [same settings screen as above]
```

### Image Flow
Same settings screen but fewer options (no page range, no pages per sheet):
```
User:  [sends photo.jpg]

Bot:   photo.jpg — image
       Ready to print. Choose your settings:

       Color:
       [ Color  ] [ B&W ]

       Orientation:
       [ Portrait ] [ Landscape ]

       Copies:
       [ - ]  1  [ + ]

       ────────────────────
       [ Print ]   [ Cancel ]
```

### Printer Status Button
```
User:  [taps "Printer Status"]
Bot:   Printer: HP LaserJet Pro
       Status: Ready
       Paper: OK
       Ink/Toner: OK
```

### Print Queue Button
```
User:  [taps "Print Queue"]
Bot:   Print Queue:
       #42 — report.pdf — Printing...
       #43 — slides.pptx — Queued

       [ Cancel #42 ]  [ Cancel #43 ]  [ Cancel All ]
```
Or if empty:
```
Bot:   Print queue is empty.
```

### Error Cases
All errors shown inline, no commands needed:
```
[sends song.mp3]
Bot:   Can't print .mp3 files.
       Supported: PDF, DOCX, PPTX, JPG, PNG, GIF, BMP, TIFF, WEBP

[sends file while printer is offline]
Bot:   Printer is offline. Check the connection and try again.
       [ Retry ]

[sends corrupt file]
Bot:   Couldn't read this file. It may be corrupted.

[file too large]
Bot:   File too large (Telegram limit is 20MB).
```

### Commands (minimal — buttons do the heavy lifting)
```
/start  - Welcome message
```
That's it. Everything else is buttons.

## Features

### MVP
- [ ] Accept PDF, DOCX, PPTX, and image files
- [ ] Convert DOCX/PPTX to PDF via LibreOffice headless
- [ ] Inline button settings screen (no text input)
- [ ] Print option: Color / B&W
- [ ] Print option: One-sided / Long edge duplex / Short edge duplex
- [ ] Print option: Portrait / Landscape
- [ ] Print option: Pages per sheet (1, 2, 4, 6, 9)
- [ ] Print option: Page range (All or Custom with text input)
- [ ] Print option: Copies (- / + buttons)
- [ ] Sensible defaults (Color, One-sided, Portrait, 1/sheet, All pages, 1 copy)
- [ ] In-place message updates (no message spam)
- [ ] Live print status (queued → printing with page progress → done)
- [ ] Cancel job button on live status message
- [ ] Printer status button
- [ ] Print queue with per-job cancel buttons + Cancel All
- [ ] Proactive notifications (job done, job failed, printer offline/online, low paper, low toner)
- [ ] Retry button on failed jobs
- [ ] Authorized users only (whitelist by Telegram user ID)
- [ ] Clear error messages with retry button where applicable

## Project Structure

```
printer_bot/
  bot.py          # Entry point, Telegram handlers
  printer.py      # CUPS printing logic
  converter.py    # Document-to-PDF conversion
  config.py       # Bot token, allowed users, default printer
  requirements.txt
```

## Dependencies

- `python-telegram-bot` - Telegram Bot API
- `pycups` - CUPS printing interface
- `Pillow` - Image handling

## System Requirements

- Linux with CUPS installed and configured
- LibreOffice (for DOCX/PPTX conversion)
- USB-connected printer, configured in CUPS
- The bot runs on the same machine the printer is plugged into

## Configuration

Environment variables or `config.py`:
- `TELEGRAM_BOT_TOKEN` - from BotFather
- `ALLOWED_USERS` - comma-separated Telegram user IDs
- `DEFAULT_PRINTER` - CUPS printer name
