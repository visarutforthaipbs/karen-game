#!/usr/bin/env python3
"""Validate local preparation artifacts; does not certify submission readiness."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "artifacts/appstore-20261013"
META = ROOT / "docs/appstore/STORE_METADATA.json"


def main():
    metadata = json.loads(META.read_text())
    checks = []
    screenshots = []
    for locale, content in metadata["localizations"].items():
        for field, maximum in [("name", 30), ("subtitle", 30),
                               ("promotional_text", 170), ("description", 4000)]:
            length = len(content[field])
            checks.append({"locale": locale, "field": field, "count": length,
                           "limit": maximum, "unit": "characters", "pass": length <= maximum})
        length = len(content["keywords"].encode("utf-8"))
        checks.append({"locale": locale, "field": "keywords", "count": length,
                       "limit": 100, "unit": "UTF-8 bytes", "pass": length <= 100})
    for device, expected in [("iphone-medium", (2556, 1179)), ("ipad13", (2752, 2064))]:
        for locale in ["th", "en"]:
            files = sorted((PACK / "screenshots" / device / locale).glob("*.png"))
            checks.append({"device": device, "locale": locale, "field": "screenshot_count",
                           "count": len(files), "pass": len(files) == 5})
            for path in files:
                with Image.open(path) as image:
                    image.load()
                    opaque = "A" not in image.getbands() or image.getchannel("A").getextrema() == (255, 255)
                    valid = image.size == expected and opaque
                    screenshots.append({"path": str(path.relative_to(ROOT)), "size": list(image.size),
                                        "opaque": opaque, "pass": valid,
                                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    success = all(row["pass"] for row in checks + screenshots)
    report = {"artifact_checks_pass": success, "submission_ready": False,
              "reason": "Candidate captures are Mac-rendered staged states; final device comparison, content rights, release build, App Store configuration and remaining owner decisions are outstanding. Support/privacy pages are live.",
              "checks": checks, "screenshots": screenshots,
              "source_commit": "308ef5605f8a4a58b003ee58a239985dda9f5bc9",
              "render_backend": "Godot 4.7.2 Mobile / Metal on Mac",
              "capture_script": "tools/appstore/capture_candidates.gd",
              "capture_warnings": "Each final capture run exited 0 with two ObjectDB instances leaked at teardown; no SCRIPT ERROR or ERROR lines in final logs."}
    PACK.mkdir(parents=True, exist_ok=True)
    (PACK / "validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"artifact_checks_pass": success, "screenshots": len(screenshots),
                      "metadata_checks": len(checks), "submission_ready": False}))
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())
