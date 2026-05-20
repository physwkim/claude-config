#!/usr/bin/env python3
"""Claude Code Stop hook: block scope-deferral without UNFIXED.

If the last assistant turn defers a discovered defect with phrases like
"scope 밖 / 별도 PR / out of scope / separate PR" but does NOT classify
it under an `UNFIXED:` block, exit 2 with a reminder so the model is
forced to either fix the defect now or properly classify it.

CLAUDE.md already bans these phrases; this hook enforces the rule at
runtime instead of trusting the model to comply.

Escape hatch: if the most recent user message contains the literal
substring `[allow-defer]`, the hook passes through silently.

Wiring (in ~/.claude/settings.json hooks.Stop[].hooks[]):

  { "type": "command",
    "command": "/Users/<you>/codes/claude-config/hooks/no-deferral-guard.py" }
"""
from __future__ import annotations

import json
import re
import sys

BANNED_PATTERNS = [
    r"스코프\s*밖",
    r"scope\s*밖",
    r"별도\s*PR",
    r"별개\s*PR",
    r"별개\s*이슈",
    r"추후\s*처리",
    r"추후\s*PR",
    r"별도로\s*처리",
    r"out\s*of\s*scope",
    r"separate\s*PR",
    r"follow[-\s]?up\s*PR",
    r"different\s*PR",
    r"defer.{0,20}PR",
]
BANNED_RE = re.compile("|".join(BANNED_PATTERNS), re.IGNORECASE)
UNFIXED_RE = re.compile(r"\bUNFIXED\b", re.IGNORECASE)
ESCAPE_TOKEN = "[allow-defer]"
# Self-reference markers: if the assistant is discussing this hook
# itself (its name or its escape token), treat as meta-discussion and
# skip — otherwise any conversation about the hook trips it.
META_RE = re.compile(r"no-deferral-guard|allow-defer", re.IGNORECASE)

REMINDER = (
    "Stop hook (no-deferral-guard): 마지막 응답에 'scope 밖 / 별도 PR / "
    "추후 처리' 류 표현이 있는데 UNFIXED 블록이 없습니다. CLAUDE.md "
    "규약상 발견된 결함은 즉시 수정하거나, 정말 미뤄야 한다면 UNFIXED "
    "블록에 구체적 사유(다른 레포 / 사용자가 명시적으로 scope 한정 / "
    "외부 의존)와 함께 명시해야 합니다. 결함을 지금 수정하거나 UNFIXED "
    "분류로 다시 보고하세요. 사용자가 의도적으로 미루려면 본인 메시지에 "
    "'[allow-defer]'를 포함하면 이 가드가 통과됩니다."
)


def _extract_text(content: object) -> str:
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for block in content:
            if isinstance(block, dict):
                if block.get("type") == "text":
                    parts.append(str(block.get("text", "")))
                elif "text" in block and isinstance(block["text"], str):
                    parts.append(block["text"])
            elif isinstance(block, str):
                parts.append(block)
        return "\n".join(parts)
    return ""


def _strip_fences(text: str) -> str:
    """Remove fenced code blocks and inline backtick spans.

    Meta-discussion of the banned phrases inside ``...`` or ```...``` is
    not a real deferral and should not trip the guard.
    """
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    text = re.sub(r"`[^`\n]+`", "", text)
    return text


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    transcript_path = payload.get("transcript_path")
    if not transcript_path:
        return 0

    try:
        with open(transcript_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except OSError:
        return 0

    last_assistant_text = ""
    last_user_text = ""
    for line in reversed(lines):
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        msg = entry.get("message") or {}
        role = msg.get("role") or entry.get("type")
        text = _extract_text(msg.get("content"))
        if role == "assistant" and not last_assistant_text and text:
            last_assistant_text = text
        elif role == "user" and not last_user_text and text:
            last_user_text = text
        if last_assistant_text and last_user_text:
            break

    if ESCAPE_TOKEN in last_user_text:
        return 0
    if not last_assistant_text:
        return 0
    if META_RE.search(last_assistant_text):
        return 0

    scrubbed = _strip_fences(last_assistant_text)
    if not BANNED_RE.search(scrubbed):
        return 0
    if UNFIXED_RE.search(last_assistant_text):
        return 0

    print(REMINDER, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
