from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from pathlib import Path

from google import genai
from google.genai import types

import config

logger = logging.getLogger(__name__)

# Lazy-init client (bot works without GEMINI_API_KEY — voice is optional)
_client: genai.Client | None = None

_MODEL = "gemini-2.5-flash"


def _get_client() -> genai.Client:
    global _client
    if _client is None:
        if not config.GEMINI_API_KEY:
            raise RuntimeError("GEMINI_API_KEY not set")
        _client = genai.Client(api_key=config.GEMINI_API_KEY)
    return _client


# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

@dataclass
class ParsedInstruction:
    """Structured output from Gemini print instruction parsing."""
    color: str | None = None        # "color" | "bw"
    sides: str | None = None        # "one" | "long" | "short"
    orientation: str | None = None  # "portrait" | "landscape"
    nup: int | None = None          # 1, 2, 4, 6, 9
    page_range: str | None = None   # "1-3,5" | "all"
    copies: int | None = None       # 1-99
    clarification: str | None = None  # Follow-up question if ambiguous
    transcript: str = ""


# JSON schema for structured output
_PARSE_SCHEMA = types.Schema(
    type=types.Type.OBJECT,
    properties={
        "color": types.Schema(
            type=types.Type.STRING,
            nullable=True,
            enum=["color", "bw"],
            description="Print color mode. null if not mentioned.",
        ),
        "sides": types.Schema(
            type=types.Type.STRING,
            nullable=True,
            enum=["one", "long", "short"],
            description="Duplex mode. null if not mentioned.",
        ),
        "orientation": types.Schema(
            type=types.Type.STRING,
            nullable=True,
            enum=["portrait", "landscape"],
            description="Page orientation. null if not mentioned.",
        ),
        "nup": types.Schema(
            type=types.Type.INTEGER,
            nullable=True,
            enum=[1, 2, 4, 6, 9],
            description="Pages per sheet. null if not mentioned.",
        ),
        "page_range": types.Schema(
            type=types.Type.STRING,
            nullable=True,
            description="Page range like '1-3,5' or 'all'. null if not mentioned.",
        ),
        "copies": types.Schema(
            type=types.Type.INTEGER,
            nullable=True,
            description="Number of copies (1-99). null if not mentioned.",
        ),
        "clarification": types.Schema(
            type=types.Type.STRING,
            nullable=True,
            description="Follow-up question in the SAME language the user spoke, if ambiguous. null if clear.",
        ),
    },
    required=[
        "color", "sides", "orientation", "nup",
        "page_range", "copies", "clarification",
    ],
)

_PARSE_PROMPT = """You are a print settings parser for a Telegram printer bot.

The user sends voice instructions about how they want to print a document.
Extract the print settings they mentioned. For any setting NOT mentioned, return null.

Available settings:
- color: "color" (full color, ملون) or "bw" (black and white, grayscale, أبيض وأسود)
- sides: "one" (single-sided, وجه واحد), "long" (two-sided normal duplex, وجهين, على الوجهين), "short" (two-sided flip on short edge)
- orientation: "portrait" (vertical, طولي) or "landscape" (horizontal, عرضي)
- nup: 1, 2, 4, 6, or 9 pages per sheet (صفحات في الورقة)
- page_range: specific pages like "1-3,5" or "all" (الكل). "first 3 pages" -> "1-3". "page 5" -> "5". "last page" -> null (unknown total, ask in clarification).
- copies: number of copies, 1-99 (نسخ / نسخة)

Rules:
1. Only extract settings the user EXPLICITLY mentioned. Do not assume or infer defaults.
2. If the instruction is ambiguous or you need more info, set "clarification" to a SHORT follow-up question in the SAME LANGUAGE the user spoke.
3. Common Arabic terms: "أبيض وأسود" = bw, "ملون" = color, "وجهين" / "على الوجهين" = long, "وجه واحد" = one, "نسخ"/"نسخة" = copies, "اطبع"/"اطبعها"/"اطبعه" = print.
4. If the user just says "print" or "اطبع" with no specific settings, return all null (use defaults).
5. If the user says something completely unrelated to printing, set all to null and clarification to a message asking what they want to do.
6. Do NOT make up settings the user didn't mention."""


# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

async def transcribe_voice(audio_path: Path) -> str:
    """Transcribe a voice note (OGG) using Gemini."""
    client = _get_client()
    audio_bytes = audio_path.read_bytes()

    response = await client.aio.models.generate_content(
        model=_MODEL,
        contents=[
            types.Part.from_bytes(data=audio_bytes, mime_type="audio/ogg"),
            "Transcribe this voice note exactly in the language spoken "
            "(Arabic or English). Return only the transcription text, "
            "nothing else.",
        ],
    )
    return response.text.strip()


async def parse_print_instruction(transcript: str) -> ParsedInstruction:
    """Parse a transcribed instruction into structured print settings."""
    client = _get_client()

    response = await client.aio.models.generate_content(
        model=_MODEL,
        contents=[f'{_PARSE_PROMPT}\n\nUser said: "{transcript}"'],
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=_PARSE_SCHEMA,
        ),
    )

    data = json.loads(response.text)

    return ParsedInstruction(
        color=data.get("color"),
        sides=data.get("sides"),
        orientation=data.get("orientation"),
        nup=data.get("nup"),
        page_range=data.get("page_range"),
        copies=data.get("copies"),
        clarification=data.get("clarification"),
        transcript=transcript,
    )


def apply_parsed_to_settings(
    parsed: ParsedInstruction, settings: dict
) -> dict:
    """Merge parsed voice instructions into existing settings.

    Only overrides fields that Gemini explicitly extracted (non-None).
    """
    if parsed.color is not None and parsed.color in ("color", "bw"):
        settings["color"] = parsed.color
    if parsed.sides is not None and parsed.sides in ("one", "long", "short"):
        settings["sides"] = parsed.sides
    if parsed.orientation is not None and parsed.orientation in (
        "portrait", "landscape"
    ):
        settings["orientation"] = parsed.orientation
    if parsed.nup is not None and parsed.nup in config.NUP_OPTIONS:
        settings["nup"] = parsed.nup
    if parsed.page_range is not None:
        settings["page_range"] = parsed.page_range
    if parsed.copies is not None:
        settings["copies"] = max(1, min(99, parsed.copies))
    return settings
