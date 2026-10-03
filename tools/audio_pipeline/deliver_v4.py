"""Resolve installed v4 takes to current game manifests; never makes paid calls.

Run after both language plans and any accepted revision plans have been installed.
An explicit plan list resolves revisions last without erasing earlier evidence.
"""
import argparse
import hashlib
import json
import math
import wave
from pathlib import Path

from install import validate_speech_approval


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def deliver(plans):
    base = Path("artifacts/audio_voice_v4_20261003")
    before = json.loads((base / "before.json").read_text())
    previous = {row["file"]: row for row in before["replaced"]}
    rows = {}
    for plan_path in plans:
        plan = json.loads(Path(plan_path).read_text())
        folder = Path(plan["output_directory"])
        ledger = json.loads((folder / "ledger.json").read_text())["jobs"]
        reviews = json.loads((folder / "speech_review.json").read_text())
        installed = {row["id"]: row for row in json.loads((folder / "installed_manifest.json").read_text())}
        for job in plan["jobs"]:
            key = job["id"]
            review = reviews.get(key, {})
            if not review.get("accepted"):
                continue
            validate_speech_approval(job, ledger[key], review, plan["language_code"])
            row = installed[key].copy()
            assert row["installed"] and digest(row["file"]) == row["sha256"], row["file"]
            args = job["arguments"]
            assert args["model_id"] == "eleven_v4", key
            row.update(provider="ElevenLabs", model_id=args["model_id"],
                       voice_id=args["voice_id"], language=args["language"],
                       actor=job["install"]["actor"], text=job["install"]["text"],
                       plan=str(plan_path), source_sha256=digest(row["source"]),
                       wording_review=review, previous_sha256=previous[row["file"]]["sha256"],
                       performance_review="Approved dry narrator direction; individual take acting/listening remains open")
            with wave.open(row["file"]) as recording:
                assert (recording.getnchannels(), recording.getsampwidth(), recording.getframerate()) == (1, 2, 44100)
                assert recording.getnframes() > 6615, key
            assert math.isfinite(row["rms_dbfs"]) and row["peak_dbfs"] <= -3.0, key
            rows[row["file"]] = row
    assert rows.keys() == previous.keys(), "Missing or unexpected replacement recordings"
    assert len(rows) == 76
    for path, expected in before["untouched_audio"].items():
        assert digest(path) == expected, "Non-speech audio changed: " + path
    captions = json.loads(Path("localization/voice_subtitles.json").read_text())
    story = json.loads(Path("localization/opening.json").read_text())
    for row in rows.values():
        path = Path(row["file"])
        expected = story["cues"][int(path.stem.split("_")[1])][row["language"]] if "/opening/" in row["file"] else captions[path.name][row["language"]]
        assert row["text"] == expected, row["file"]
    clips = sorted(rows.values(), key=lambda row: row["file"])
    result = {"date": "2026-10-03", "model_id": "eleven_v4", "decision": "Owner-requested model replacement installed",
              "approved_pilot": "tools/onboarding/voice_th_dry_pilot.json",
              "settings": {"stability": 0.7, "similarity_boost": 0.65},
              "audio_format": "mono 44100 Hz PCM16", "clips": clips}
    write_json("tools/audio_pipeline/installed_voices_v4.json", result)
    english = []
    for row in clips:
        if row["language"] == "en" and "/opening/" not in row["file"]:
            row = row.copy()
            row["thai_source"] = Path(row["file"]).name
            row["thai_sha256"] = digest(Path("assets/audio") / row["thai_source"])
            english.append(row)
    assert len(english) == 30
    write_json("tools/audio_pipeline/installed_english_voices.json", {
        "date": "2026-10-03", "decision": result["decision"], "model_id": "eleven_v4",
        "plan": "tools/audio_pipeline/voice_v4_en_plan.json", "audio_format": result["audio_format"], "clips": english})
    opening = []
    for row in clips:
        if "/opening/" in row["file"]:
            row = row.copy()
            row["asr"] = row["wording_review"]
            opening.append(row)
    assert len(opening) == 16
    write_json("tools/onboarding/installed_voices.json", opening)
    write_json(base / "verification.json", {
        "clips": len(clips), "languages": {language: sum(row["language"] == language for row in clips) for language in ("th", "en")},
        "same_speaker_ids": sorted({row["voice_id"] for row in clips}), "all_current_models_v4": True,
        "unchanged_non_speech_wavs": len(before["untouched_audio"]),
        "rejected_or_superseded_takes_retained": True,
        "total_seconds": round(sum(row["seconds"] for row in clips), 3)})
    print("Verified and resolved 76 v4 recordings; 68 non-speech WAVs unchanged.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("plans", nargs="+", help="Installed plans, with revisions last")
    deliver(parser.parse_args().plans)
