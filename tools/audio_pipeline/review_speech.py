"""Review speech wording with Scribe; ASR does not review acting or pronunciation.

Plans default to language_code="tha" and max_cer=0.10. English plans should use
"eng" and 0 for exact normalized wording, with listening/manual mismatch review.
MCP imports and configuration are loaded only when uncached work is pending.
"""
import argparse
import asyncio
import hashlib
import json
import math
import os
import re
import tomllib
import unicodedata
from pathlib import Path

REVIEW_NOTE = "ASR wording only; listening/acting/pronunciation review remains open"


def clean(text):
    # Preserve the original Thai character/mark handling and ignore Latin case.
    normalized = unicodedata.normalize("NFC", unicodedata.normalize("NFC", text).casefold())
    return "".join(c for c in normalized if c.isalnum() or "\u0e00" <= c <= "\u0e7f")


def distance(a, b):
    row = list(range(len(b) + 1))
    for i, c in enumerate(a, 1):
        new = [i]
        for j, d in enumerate(b, 1):
            new.append(min(new[-1] + 1, row[j] + 1, row[j - 1] + (c != d)))
        row = new
    return row[-1]


def review_options(plan):
    language = plan.get("language_code", "tha")
    if not isinstance(language, str) or not re.fullmatch(r"[a-z]{3}", language):
        raise ValueError("language_code must be a three-letter ISO 639-3 code (tha or eng)")
    threshold = float(plan.get("max_cer", .10))
    if not math.isfinite(threshold) or not 0 <= threshold <= 1:
        raise ValueError("max_cer must be finite and between 0 and 1")
    return language, threshold


def assess_transcript(expected, heard, language, threshold, source_hash):
    target = clean(expected)
    if not target:
        raise ValueError("Speech text must contain words")
    normalized = clean(heard)
    cer = distance(target, normalized) / len(target)
    return {
        "expected": expected, "heard": heard, "cer": round(cer, 4),
        "accepted": bool(normalized) and cer <= threshold,
        "language_code": language, "max_cer": threshold,
        "source_sha256": source_hash, "status": "reviewed", "review": REVIEW_NOTE,
    }


def error_review(expected, language, threshold, error, source_hash=None):
    return {
        "expected": expected, "heard": "", "cer": None, "accepted": False,
        "language_code": language, "max_cer": threshold,
        "source_sha256": source_hash, "status": "error", "error": str(error),
        "review": REVIEW_NOTE,
    }


def pending_reviews(plan, ledger, reviews, retry_errors=False):
    """Reuse matching decisions; never retry ambiguous/error ASR calls implicitly."""
    language, threshold = review_options(plan)
    pending = []
    for job in plan["jobs"]:
        key, spec = job["id"], job["install"]
        record = ledger["jobs"].get(key, {})
        if not spec.get("speech") or record.get("status") != "complete":
            continue
        expected = spec["text"]
        if not isinstance(expected, str) or not clean(expected):
            raise ValueError(f"Invalid speech text for {key}")
        try:
            source = Path(record["files"][0])
            source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        except (OSError, KeyError, IndexError, TypeError) as error:
            reviews[key] = error_review(expected, language, threshold, error)
            continue
        old = reviews.get(key, {})
        matching = (
            old.get("expected") == expected
            and old.get("language_code", "tha") == language
            and old.get("source_sha256", source_hash) == source_hash
        )
        if matching and old.get("status") in ("error", "pending") and not retry_errors:
            continue
        if matching and old.get("status") not in ("error", "pending") and isinstance(old.get("heard"), str):
            if threshold < float(old.get("max_cer", .10)) or not clean(old["heard"]):
                # A tighter plan cannot inherit a looser auto-acceptance. Reuse
                # the transcript without another call; review mismatches again.
                reviews[key] = assess_transcript(expected, old["heard"], language, threshold, source_hash)
            continue
        reviews[key] = error_review(expected, language, threshold, "ASR review pending; not accepted", source_hash)
        reviews[key]["status"] = "pending"
        pending.append((job, source, source_hash))
    return pending


def save_reviews(path, reviews):
    # Keep resumable decisions intact even if a later call fails/interruption.
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(reviews, ensure_ascii=False, indent=2))
    temporary.replace(path)


async def review_pending(session, pending, reviews, path, language, threshold):
    for job, source, source_hash in pending:
        key, expected = job["id"], job["install"]["text"]
        try:
            result = await session.call_tool("speech_to_text", {
                "input_file_path": str(source), "language_code": language,
                "save_transcript_to_file": False, "return_transcript_to_client_directly": True,
            })
            heard = " ".join(c.text for c in result.content if c.type == "text")
            if result.isError:
                raise RuntimeError(heard or "ASR returned an error")
            decision = assess_transcript(expected, heard, language, threshold, source_hash)
        except Exception as error:
            decision = error_review(expected, language, threshold, error, source_hash)
        reviews[key] = decision
        save_reviews(path, reviews)
        print(key, decision["cer"], decision.get("error", decision["heard"]), flush=True)


async def main(plan_path, retry_errors=False):
    plan = json.loads(Path(plan_path).read_text())
    base = Path(plan["output_directory"])
    ledger = json.loads((base / "ledger.json").read_text())
    path = base / "speech_review.json"
    reviews = json.loads(path.read_text()) if path.exists() else {}
    language, threshold = review_options(plan)
    pending = pending_reviews(plan, ledger, reviews, retry_errors)
    save_reviews(path, reviews)
    if not pending:
        print("No pending speech reviews; existing decisions retained.")
        return
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
    cfg = tomllib.loads((Path.home() / ".codex/config.toml").read_text())["mcp_servers"]["elevenlabs"]
    env = dict(os.environ)
    env.update(cfg.get("env", {}))
    env["ELEVENLABS_MCP_BASE_PATH"] = str(Path.cwd().resolve())
    async with stdio_client(StdioServerParameters(command=cfg["command"], args=cfg.get("args", []), env=env)) as (r, w):
        async with ClientSession(r, w) as session:
            await session.initialize()
            await review_pending(session, pending, reviews, path, language, threshold)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", nargs="?", default="tools/audio_pipeline/voice_plan.json")
    parser.add_argument("--retry-errors", action="store_true", help="Explicitly retry failed ASR calls (may incur cost)")
    args = parser.parse_args()
    asyncio.run(main(args.plan, args.retry_errors))
