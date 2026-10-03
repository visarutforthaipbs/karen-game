#!/usr/bin/env python3
"""Qualify Godot 4.7 format-4 release payloads against current project sources.

Accepts a standalone Mac .pck or a Windows/Linux executable with Godot's
GDPC size footer. This checks payload integrity, export exclusions,
font notices, localization, and all 76 approved imported voice resources.
It does not replace engine loading, signing, or native platform QA.

Example: python3 tools/release/validate_pack.py game.pck game.exe game.x86_64
         --output artifacts/release/payload-validation.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import BinaryIO

MAGIC = 0x43504447
HEADER_SIZE = 104
MAX_FILES = 100_000
MAX_PATH = 16_384
CHUNK = 1024 * 1024
FORBIDDEN = (
    "tests/", "tools/", "artifacts/", "docs/", "build/", "server/",
    "assets/audio/v11_candidates/", "assets/concept_art/", "assets/reference/",
)
CATALOGS = ("messages.json", "opening.json", "voice_subtitles.json")


class InvalidPack(ValueError):
    pass


def exact(stream: BinaryIO, size: int) -> bytes:
    data = stream.read(size)
    if len(data) != size:
        raise InvalidPack("truncated PCK header or directory")
    return data


def digest_region(stream: BinaryIO, offset: int, size: int, algorithm: str) -> str:
    stream.seek(offset)
    digest = hashlib.new(algorithm)
    remaining = size
    while remaining:
        data = stream.read(min(CHUNK, remaining))
        if not data:
            raise InvalidPack("truncated PCK resource data")
        digest.update(data)
        remaining -= len(data)
    return digest.hexdigest()


def file_sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return digest_region(stream, 0, path.stat().st_size, "sha256")


def canonical(path: str) -> str:
    if (not path or "\\" in path or "\0" in path or path.startswith("/")
            or str(PurePosixPath(path)) != path
            or any(part in (".", "..") for part in path.split("/"))):
        raise InvalidPack(f"noncanonical resource path: {path!r}")
    return path


@dataclass(frozen=True)
class Entry:
    path: str
    offset: int  # Absolute offset in the input executable/PCK.
    size: int
    md5: str


class Pack:
    def __init__(self, path: Path, offset: int | None = None,
                 size: int | None = None):
        self.path = path
        total = path.stat().st_size
        with path.open("rb") as stream:
            if offset is not None:
                self.start = offset
                self.size = size if size is not None else total - offset
                self.container = "explicit-offset"
            elif exact(stream, 4) == struct.pack("<I", MAGIC):
                self.start, self.size, self.container = 0, total, "standalone"
            else:
                if total < HEADER_SIZE + 12:
                    raise InvalidPack("input is neither a PCK nor a GDPC-footer executable")
                stream.seek(total - 12)
                pack_size, magic = struct.unpack("<QI", exact(stream, 12))
                if magic != MAGIC or pack_size < HEADER_SIZE or pack_size > total - 12:
                    raise InvalidPack("no valid embedded GDPC footer; provide an explicit offset/size")
                self.start = total - 12 - pack_size
                self.size = pack_size
                self.container = "embedded-footer"
            if (self.start < 0 or self.size < HEADER_SIZE
                    or self.start + self.size > total):
                raise InvalidPack("PCK range exceeds input file bounds")
            stream.seek(self.start)
            header = exact(stream, HEADER_SIZE)
            magic, fmt, major, minor, patch, flags = struct.unpack_from("<6I", header)
            if magic != MAGIC or fmt != 4:
                raise InvalidPack(f"unsupported PCK magic/format ({magic:#x}, {fmt}); expected format 4")
            # This release uses relative file-base offsets, unencrypted resources.
            # Do not silently interpret old/unknown or encrypted formats.
            if flags != 2:
                raise InvalidPack(f"unsupported PCK flags {flags:#x}; expected relative-base flag 2")
            self.engine = f"{major}.{minor}.{patch}"
            self.format = fmt
            self.base, self.directory = struct.unpack_from("<2Q", header, 24)
            if not HEADER_SIZE <= self.base <= self.directory <= self.size - 4:
                raise InvalidPack("invalid PCK data/directory bounds")
            directory_end = self.start + self.size
            stream.seek(self.start + self.directory)
            count = struct.unpack("<I", exact(stream, 4))[0]
            if count == 0 or count > MAX_FILES:
                raise InvalidPack(f"invalid PCK file count {count}")
            self.entries: dict[str, Entry] = {}
            for _ in range(count):
                if stream.tell() + 4 > directory_end:
                    raise InvalidPack("directory entry exceeds PCK bounds")
                length = struct.unpack("<I", exact(stream, 4))[0]
                if (length == 0 or length > MAX_PATH
                        or stream.tell() + length + 36 > directory_end):
                    raise InvalidPack("invalid PCK directory path length")
                padded = exact(stream, length)
                raw = padded.rstrip(b"\0")
                try:
                    name = canonical(raw.decode("utf-8"))
                except UnicodeDecodeError as error:
                    raise InvalidPack("invalid UTF-8 directory path") from error
                relative, resource_size = struct.unpack("<2Q", exact(stream, 16))
                md5 = exact(stream, 16).hex()
                entry_flags = struct.unpack("<I", exact(stream, 4))[0]
                if entry_flags != 0:
                    raise InvalidPack(f"unsupported resource flags for {name}: {entry_flags:#x}")
                if name in self.entries:
                    raise InvalidPack(f"duplicate resource path: {name}")
                data_offset = self.base + relative
                if (data_offset < self.base
                        or data_offset + resource_size > self.directory):
                    raise InvalidPack(f"resource outside PCK data region: {name}")
                self.entries[name] = Entry(name, self.start + data_offset, resource_size, md5)

    def read(self, name: str) -> bytes:
        entry = self.entries[name]
        if entry.size > CHUNK:
            raise InvalidPack(f"metadata unexpectedly exceeds 1 MiB: {name}")
        with self.path.open("rb") as stream:
            stream.seek(entry.offset)
            return exact(stream, entry.size)


def remap(text: str) -> str:
    section = re.search(r"(?ms)^\[remap\]\s*(.*?)(?=^\[|\Z)", text)
    match = re.search(r'^path="res://([^"\r\n]+)"$', section[1], re.M) if section else None
    if not match:
        raise InvalidPack("missing imported resource remap path")
    return canonical(match[1])


def remap_targets(text: str) -> set[str]:
    section = re.search(r"(?ms)^\[remap\]\s*(.*?)(?=^\[|\Z)", text)
    if not section:
        raise InvalidPack("missing imported resource remap section")
    # Compressed textures select path.s3tc/path.etc2 by platform feature.
    paths = re.findall(r'^path(?:\.[\w]+)?="res://([^"\r\n]+)"$', section[1], re.M)
    if not paths:
        raise InvalidPack("missing imported resource remap targets")
    return {canonical(path) for path in paths}


def forbidden_imports(project: Path) -> set[str]:
    # Exclusion must remove hidden imported bytes, not only source .import entries.
    targets: set[str] = set()
    imports = [project / "screenshot_chibi_gameplay.png.import"]
    for prefix in FORBIDDEN:
        directory = project / prefix
        if directory.exists():
            imports.extend(directory.rglob("*.import"))
    for path in imports:
        if path.is_file():
            targets.update(remap_targets(path.read_text(encoding="utf-8")))
    # Scratch exports sometimes copy production .import metadata unchanged.
    # A resource genuinely shared by an allowed production asset is still needed.
    allowed: set[str] = set()
    for directory in ("assets", "scenes", "ui", "scripts"):
        for path in (project / directory).rglob("*.import"):
            if not path.relative_to(project).as_posix().startswith(FORBIDDEN):
                allowed.update(remap_targets(path.read_text(encoding="utf-8")))
    return targets - allowed


def validate(path: Path, project: Path, offset: int | None = None,
             size: int | None = None) -> dict:
    pack = Pack(path, offset, size)
    failures: list[str] = []
    compared: list[dict] = []
    voices_verified = 0
    with path.open("rb") as stream:
        artifact_hash = digest_region(stream, 0, path.stat().st_size, "sha256")
        pack_hash = digest_region(stream, pack.start, pack.size, "sha256")
        for entry in pack.entries.values():
            if digest_region(stream, entry.offset, entry.size, "md5") != entry.md5:
                failures.append(f"PCK integrity mismatch: {entry.path}")
        excluded_imports = forbidden_imports(project)
        for name in pack.entries:
            if (name.startswith(FORBIDDEN) or name.endswith(".md")
                    or name.startswith("screenshot_chibi_gameplay.png")
                    or name in excluded_imports):
                failures.append(f"excluded development resource shipped: {name}")

        def compare(name: str, source: Path) -> bool:
            entry = pack.entries.get(name)
            if not source.is_file():
                failures.append(f"current source missing: {source}")
                return False
            if entry is None:
                failures.append(f"required exported resource missing: {name}")
                return False
            expected = file_sha256(source)
            actual = digest_region(stream, entry.offset, entry.size, "sha256")
            compared.append({"path": name, "source_sha256": expected,
                             "pack_sha256": actual, "matches": actual == expected})
            if expected != actual:
                failures.append(f"current source/export hash mismatch: {name}")
            return expected == actual

        for name in CATALOGS:
            compare("localization/" + name, project / "localization" / name)
        for name in ("OFL-Kanit.txt", "OFL-ChakraPetch.txt"):
            compare("assets/fonts/" + name, project / "assets/fonts" / name)
        if "project.binary" not in pack.entries:
            failures.append("exported project.binary missing")

        registry_path = project / "tools/audio_pipeline/installed_voices_v4.json"
        registry = json.loads(registry_path.read_text(encoding="utf-8"))
        clips = registry.get("clips", [])
        if not isinstance(clips, list) or len(clips) != 76:
            raise InvalidPack("approved v4 voice registry must contain exactly 76 clips")
        seen: set[str] = set()
        for clip in clips:
            filename = canonical(clip["file"])
            if filename in seen:
                raise InvalidPack(f"duplicate approved voice: {filename}")
            seen.add(filename)
            if not filename.startswith("assets/audio/") or not filename.endswith(".wav"):
                raise InvalidPack(f"unexpected approved voice path: {filename}")
            source = project / filename
            if not clip.get("installed") or clip.get("model_id") != "eleven_v4":
                failures.append(f"voice lacks installed v4 approval: {filename}")
                continue
            if not source.is_file() or file_sha256(source) != clip.get("sha256"):
                failures.append(f"approved voice source hash mismatch: {filename}")
                continue
            source_import = Path(str(source) + ".import")
            if not source_import.is_file():
                failures.append(f"voice import metadata missing: {filename}")
                continue
            imported = remap(source_import.read_text(encoding="utf-8"))
            packed_import = filename + ".import"
            if packed_import not in pack.entries:
                failures.append(f"exported voice remap missing: {packed_import}")
                continue
            if remap(pack.read(packed_import).decode("utf-8")) != imported:
                failures.append(f"exported voice remap differs from current source: {filename}")
                continue
            if compare(imported, project / imported):
                voices_verified += 1

        # Both bundled font families must resolve to the current imported bytes.
        for font in sorted((project / "assets/fonts").glob("*.ttf.import")):
            name = font.relative_to(project).as_posix()
            imported = remap(font.read_text(encoding="utf-8"))
            if name not in pack.entries:
                failures.append(f"exported font remap missing: {name}")
            elif remap(pack.read(name).decode("utf-8")) != imported:
                failures.append(f"exported font remap differs from source: {name}")
            else:
                compare(imported, project / imported)

    return {
        "file": str(path.resolve()), "bytes": path.stat().st_size,
        "artifact_sha256": artifact_hash, "pack_sha256": pack_hash,
        "container": pack.container, "pack_offset": pack.start,
        "pack_bytes": pack.size, "format": pack.format, "engine": pack.engine,
        "entries": len(pack.entries), "voices_verified": voices_verified,
        "payload_index": [{"path": entry.path, "offset": entry.offset,
                           "bytes": entry.size, "md5": entry.md5}
                          for entry in pack.entries.values()],
        "voice_registry_sha256": file_sha256(registry_path),
        "current_source_comparisons": compared,
        "failures": failures, "passed": not failures,
        "scope": "Payload checks only; engine load, signing, and native platform QA are separate.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packs", type=Path, nargs="+")
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path, help="write JSON qualification report")
    parser.add_argument("--pack-offset", type=int, help="explicit PCK start for one input only")
    parser.add_argument("--pack-size", type=int, help="explicit PCK length; requires --pack-offset")
    args = parser.parse_args()
    if ((args.pack_offset is not None and len(args.packs) != 1)
            or (args.pack_size is not None and args.pack_offset is None)):
        parser.error("explicit offset/size applies to exactly one input; size requires offset")
    results = []
    for path in args.packs:
        try:
            result = validate(path, args.project.resolve(), args.pack_offset, args.pack_size)
        except (OSError, ValueError, KeyError, TypeError, struct.error) as error:
            result = {"file": str(path.resolve()), "passed": False, "failures": [str(error)]}
        results.append(result)
        print(f"{'PASS' if result['passed'] else 'FAIL'} {path}: "
              f"{result.get('entries', 0)} entries, {result.get('voices_verified', 0)}/76 exact voices")
        for failure in result["failures"]:
            print(f"  {failure}", file=sys.stderr)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps({"results": results}, indent=2) + "\n", encoding="utf-8")
    return 0 if all(row["passed"] for row in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
