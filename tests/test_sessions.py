"""Exercise session environment isolation without starting a compositor."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Sessions(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)
        self.bin = self.path / "bin"
        self.bin.mkdir()
        for name in ("niri-session", "uwsm", "dms", "noctalia"):
            program = self.bin / name
            program.write_text("#!/usr/bin/python3\nimport json, os, sys\nprint(json.dumps({'args':sys.argv[1:], 'env':dict(os.environ)}))\n")
            program.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.path), PATH=f"{self.bin}:/usr/bin:/bin")
        self.env.pop("XDG_CONFIG_HOME", None)
        self.env.pop("XDG_CACHE_HOME", None)

    def session(self, compositor, shell):
        source = (ROOT / "system_files/usr/bin/bazzite-lab-session").read_text()
        source = source.replace("/usr/share/bazzite-lab", str(ROOT / "system_files/usr/share/bazzite-lab"))
        result = subprocess.run(["bash", "-c", source, "session", compositor, shell], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_niri_keeps_application_config_home_and_preserves_edits(self):
        first = self.session("niri", "dms")
        self.assertNotIn("XDG_CONFIG_HOME", first["env"])
        config = Path(first["env"]["NIRI_CONFIG"])
        config.write_text("// User configuration must survive subsequent logins\n")
        self.session("niri", "dms")
        self.assertEqual(config.read_text(), "// User configuration must survive subsequent logins\n")
        other = self.session("niri", "noctalia")
        self.assertNotEqual(first["env"]["NIRI_CONFIG"], other["env"]["NIRI_CONFIG"])

    def test_hyprland_uses_profile_lua_without_redirecting_apps(self):
        result = self.session("hyprland", "noctalia")
        self.assertNotIn("XDG_CONFIG_HOME", result["env"])
        self.assertEqual(result["args"][:4], ["start", "--", "/usr/bin/Hyprland", "--config"])
        self.assertTrue(result["args"][-1].endswith("hyprland-noctalia/hypr/hyprland.lua"))

    def test_shells_get_distinct_configuration_and_cache(self):
        outputs = []
        for profile in ("niri-dms", "niri-noctalia", "hyprland-dms"):
            env = dict(self.env, BAZZITE_LAB_PROFILE=profile, BAZZITE_LAB_CONFIG_ROOT=str(self.path / "config"))
            result = subprocess.run(["bash", str(ROOT / "system_files/usr/bin/bazzite-lab-shell")], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            outputs.append(json.loads(result.stdout)["env"])
        self.assertEqual(len({x["XDG_CONFIG_HOME"] for x in outputs}), 3)
        self.assertEqual(len({x["XDG_CACHE_HOME"] for x in outputs}), 3)

    def test_unsupported_session_fails_before_creating_config(self):
        result = subprocess.run(["bash", str(ROOT / "system_files/usr/bin/bazzite-lab-session"), "niri", "unknown"], env=self.env, capture_output=True)
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.path / ".config").exists())


if __name__ == "__main__":
    unittest.main()
