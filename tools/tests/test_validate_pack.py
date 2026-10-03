"""Payload safeguards using synthetic format-4 packs and isolated sources.

These fixtures test byte parsing and release checks, not audio decoding or
native executable behavior. Real exported payloads are qualified separately.
"""
import hashlib, importlib.util, json, pathlib, struct, sys, tempfile, unittest
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("validate_pack", ROOT / "tools/release/validate_pack.py")
m = importlib.util.module_from_spec(spec); sys.modules[spec.name] = m; spec.loader.exec_module(m)

def write_pack(path, rows, prefix=b"", fmt=4, flags=2):
    body = bytearray(112)
    entries = []
    for name, data in rows.items():
        relative = len(body) - 112
        body.extend(data)
        body.extend(b"\0" * (-len(body) % 16))
        entries.append((name, relative, len(data), hashlib.md5(data).digest()))
    directory = len(body)
    body.extend(struct.pack("<I", len(entries)))
    for name, offset, size, md5 in entries:
        encoded = name.encode(); encoded += b"\0" * (-len(encoded) % 4)
        body.extend(struct.pack("<I", len(encoded)) + encoded + struct.pack("<2Q", offset, size) + md5 + struct.pack("<I", 0))
    struct.pack_into("<6I2Q", body, 0, m.MAGIC, fmt, 4, 7, 2, flags, 112, directory)
    path.write_bytes(prefix + body + (struct.pack("<QI", len(body), m.MAGIC) if prefix else b""))

class QualificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.project = pathlib.Path(self.temp.name) / "project"; self.project.mkdir()
        self.path = pathlib.Path(self.temp.name) / "game.pck"
        self.rows = {"project.binary": b"project fixture"}
        def source(name, data):
            path = self.project / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(data)
            return path
        self.source = source
        for name in m.CATALOGS:
            resource = "localization/" + name; data = b'{"fixture": "English / Thai"}'
            source(resource, data); self.rows[resource] = data
        for name in ("OFL-Kanit.txt", "OFL-ChakraPetch.txt"):
            resource = "assets/fonts/" + name; data = b"SIL Open Font License fixture"
            source(resource, data); self.rows[resource] = data
        clips = []
        for i in range(76):
            filename = f"assets/audio/voice_{i}.wav"; wave = f"approved WAV {i}".encode(); source(filename, wave)
            target = f".godot/imported/voice_{i}.sample"; data = f"imported recording {i}".encode()
            source(target, data); self.rows[target] = data
            metadata = f'[remap]\npath="res://{target}"\n\n[deps]\n'.encode()
            source(filename + ".import", metadata); self.rows[filename + ".import"] = metadata
            clips.append(dict(file=filename, sha256=hashlib.sha256(wave).hexdigest(), installed=True, model_id="eleven_v4"))
        source("tools/audio_pipeline/installed_voices_v4.json", json.dumps(dict(clips=clips)).encode())
        write_pack(self.path, self.rows)
    def qualify(self): return m.validate(self.path, self.project)
    def test_current_standalone(self):
        r = self.qualify(); self.assertTrue(r["passed"], r["failures"]); self.assertEqual(r["voices_verified"], 76)
    def test_embedded_footer_exact_bytes(self):
        original = self.qualify(); write_pack(self.path, self.rows, prefix=b"MZ fixture prefix" * 7)
        r = self.qualify(); self.assertTrue(r["passed"], r["failures"])
        self.assertEqual(r["pack_offset"], 17 * 7); self.assertEqual(r["pack_sha256"], original["pack_sha256"])
    def test_explicit_offset(self):
        write_pack(self.path, self.rows, prefix=b"ELF fixture")
        p = m.Pack(self.path); r = m.validate(self.path, self.project, p.start, p.size)
        self.assertTrue(r["passed"])
    def test_stale_catalog_fails(self):
        self.source("localization/messages.json", b"newly changed source")
        self.assertTrue(any("current source/export hash mismatch: localization/messages" in f for f in self.qualify()["failures"]))
    def test_approved_wave_changed_fails(self):
        self.source("assets/audio/voice_0.wav", b"unreviewed recording")
        self.assertTrue(any("approved voice source hash mismatch" in f for f in self.qualify()["failures"]))
    def test_missing_license_fails(self):
        del self.rows["assets/fonts/OFL-Kanit.txt"]; write_pack(self.path, self.rows)
        self.assertTrue(any("OFL-Kanit.txt" in f for f in self.qualify()["failures"]))
    def test_unwanted_hidden_resource_fails(self):
        target = ".godot/imported/dev-font.fontdata"
        self.source("server/download/font.ttf.import", f'[remap]\npath="res://{target}"\n'.encode())
        self.rows[target] = b"development font"; write_pack(self.path, self.rows)
        self.assertTrue(any("excluded development resource shipped: " + target == f for f in self.qualify()["failures"]))
    def test_shared_production_import_remains_allowed(self):
        text = (self.project / "assets/audio/voice_0.wav.import").read_bytes()
        self.source("artifacts/copied-voice.wav.import", text)
        self.assertTrue(self.qualify()["passed"])
    def test_integrity_corruption_fails(self):
        with self.path.open("r+b") as f: f.seek(112); f.write(b"X")
        self.assertTrue(any("PCK integrity mismatch: project.binary" in f for f in self.qualify()["failures"]))
    def test_parent_path_rejected(self):
        write_pack(self.path, {"../hidden": b"data"})
        with self.assertRaises(m.InvalidPack): m.Pack(self.path)
    def test_truncation_rejected(self):
        self.path.write_bytes(self.path.read_bytes()[:-10])
        with self.assertRaises(m.InvalidPack): m.Pack(self.path)
    def test_unsupported_flags_rejected(self):
        write_pack(self.path, self.rows, flags=3)
        with self.assertRaises(m.InvalidPack): m.Pack(self.path)
    def test_unsupported_format_rejected(self):
        write_pack(self.path, self.rows, fmt=3)
        with self.assertRaises(m.InvalidPack): m.Pack(self.path)
    def test_bad_footer_rejected(self):
        write_pack(self.path, self.rows, prefix=b"PE prefix")
        self.path.write_bytes(self.path.read_bytes()[:-4] + b"BAD!")
        with self.assertRaises(m.InvalidPack): m.Pack(self.path)
    def test_resource_overrun_rejected(self):
        # First directory entry size must stay before the directory itself.
        p = m.Pack(self.path)
        with self.path.open("r+b") as f:
            f.seek(p.directory + 4); n = struct.unpack("<I", f.read(4))[0]
            f.seek(n + 8, 1); f.write(struct.pack("<Q", 2 ** 63))
        with self.assertRaises(m.InvalidPack): m.Pack(self.path)

if __name__ == "__main__": unittest.main(verbosity=2)
