"""Release safeguards: a zero exit code is not proof an export exists or works."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile


BUILDER = Path(__file__).resolve().parents[1] / "build.sh"
FAKE_ENGINE = '''#!/usr/bin/env python3
import os, pathlib, subprocess, sys, zipfile
args = sys.argv[1:]
mode = os.environ.get("EXPORT_TEST_MODE", "ok")
if "--version" in args:
    print("4.7.2.fixture")
elif "--import" in args:
    if mode == "import_exit": sys.exit(42)
    if mode == "import_error": print("SCRIPT ERROR: fixture import failure")
elif "--export-release" in args:
    if mode == "source_drift":
        pathlib.Path("ui").mkdir(exist_ok=True)
        pathlib.Path("ui/changed.gd").write_text("extends Control\\n")
    if mode == "head_drift":
        subprocess.run(["git", "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                        "commit", "--allow-empty", "-qm", "other agent commit"], check=True)
    if mode == "export_error":
        print("ERROR: fixture export failure")
        sys.exit(0)
    if mode == "missing_target": sys.exit(0)
    target = pathlib.Path(args[-1])
    if target.suffix == ".zip":
        with zipfile.ZipFile(target, "w") as archive:
            archive.writestr("Under Two Skies.app/Contents/MacOS/Under Two Skies", "fixture")
    else:
        target.write_bytes(b"nonempty executable fixture")
        target.chmod(0o755)
'''


class BuildSafeguards(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "tools").mkdir()
        shutil.copy2(BUILDER, self.root / "tools/build.sh")
        (self.root / ".gitignore").write_text("build/\n")
        self.engine = self.root / "fixture-godot"
        self.engine.write_text(FAKE_ENGINE)
        self.engine.chmod(0o755)
        for args in (["init", "-q"], ["add", "."],
                     ["-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                      "commit", "-qm", "fixture"]):
            subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True)

    def run_build(self, mode="ok", *presets):
        return subprocess.run(["bash", "tools/build.sh", *presets], cwd=self.root,
                              env={**os.environ, "GODOT": str(self.engine),
                                   "EXPORT_TEST_MODE": mode}, capture_output=True, text=True)

    def test_nonzero_import_cannot_produce_archive(self):
        self.assertNotEqual(self.run_build("import_exit", "Linux").returncode, 0)
        self.assertFalse(list(self.root.glob("build/**/*.zip")))

    def test_import_script_error_with_zero_exit_is_failure(self):
        result = self.run_build("import_error", "Linux")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture import failure", result.stderr)

    def test_export_error_with_zero_exit_is_failure(self):
        self.assertNotEqual(self.run_build("export_error", "Linux").returncode, 0)
        self.assertFalse(list(self.root.glob("build/**/*.zip")))

    def test_missing_export_cannot_be_zipped(self):
        result = self.run_build("missing_target", "Linux")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing or empty export", result.stderr)

    def test_existing_build_is_preserved_and_not_mixed(self):
        old = self.root / "build/old/UnderTwoSkies-Windows"
        old.mkdir(parents=True)
        (old / "UnderTwoSkies.exe").write_bytes(b"prior release")
        self.assertEqual(self.run_build("ok", "Linux").returncode, 0)
        self.assertEqual((old / "UnderTwoSkies.exe").read_bytes(), b"prior release")
        self.assertEqual(len(list(self.root.glob("build/**/*.zip"))), 1)
        archive = next(self.root.glob("build/**/UnderTwoSkies-Linux.zip"))
        with zipfile.ZipFile(archive) as package:
            self.assertIn("UnderTwoSkies-Linux/UnderTwoSkies.x86_64", package.namelist())

    def test_separate_arguments_export_each_requested_platform(self):
        result = self.run_build("ok", "Windows", "Linux")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(list(self.root.glob("build/**/*.zip"))), 2)

    def test_uncommitted_runtime_file_blocks_release_stamp(self):
        (self.root / "ui").mkdir()
        (self.root / "ui/new.gd").write_text("extends Control\n")
        result = self.run_build("ok", "Linux")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("uncommitted runtime files", result.stderr)

    def test_mid_export_edit_cannot_receive_qualified_manifest(self):
        result = self.run_build("source_drift", "Linux")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("changed during export", result.stderr)
        self.assertFalse(list(self.root.glob("build/**/source-manifest.json")))

    def test_mid_export_commit_cannot_receive_qualified_manifest(self):
        result = self.run_build("head_drift", "Linux")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("changed during export", result.stderr)
        self.assertFalse(list(self.root.glob("build/**/source-manifest.json")))

    def test_engine_uses_committed_snapshot_and_no_worktree_cache(self):
        (self.root / ".godot").mkdir()
        (self.root / ".godot/untracked-cache").write_text("prior cached runtime")
        result = self.run_build("ok", "Linux")
        self.assertEqual(result.returncode, 0, result.stderr)
        source = next(self.root.glob("build/*/source"))
        self.assertTrue((source / "tools/build.sh").exists())
        self.assertFalse((source / ".godot/untracked-cache").exists())


if __name__ == "__main__":
    unittest.main()
