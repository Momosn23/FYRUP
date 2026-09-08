"""Synthetic fixtures only: never print or load a private signing identity."""

import importlib.util
from pathlib import Path
import plistlib
import subprocess
import sys
import unittest


SCRIPT = Path(__file__).with_name("verify-signing-profile.py")
spec = importlib.util.spec_from_file_location("verify_signing_profile", SCRIPT)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


def valid_profile(target="main"):
    return {"Entitlements": {
        "application-identifier": validator.TARGET_IDENTIFIERS[target],
        "com.apple.security.application-groups": [validator.APP_GROUP],
        "com.apple.developer.healthkit": True,
        "com.apple.developer.weatherkit": True,
        "aps-environment": "production",
        "com.apple.developer.applesignin": ["Default"],
    }}


class SigningProfileTests(unittest.TestCase):
    def test_xml_and_binary_profiles_are_accepted(self):
        for fmt in (plistlib.FMT_XML, plistlib.FMT_BINARY):
            with self.subTest(format=fmt):
                validator.validate_profile(plistlib.dumps(valid_profile(), fmt=fmt))

    def test_nonseekable_stdin_pipe_accepts_both_formats(self):
        for fmt in (plistlib.FMT_XML, plistlib.FMT_BINARY):
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "main"],
                input=plistlib.dumps(valid_profile(), fmt=fmt),
                capture_output=True, check=False, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            self.assertIn(b"Verified FYRUP main profile", result.stdout)

    def test_live_profile_requires_its_identifier_and_shared_group(self):
        validator.validate_profile(plistlib.dumps(valid_profile("live")), "live")
        for name, value in (
            ("application-identifier", validator.TARGET_IDENTIFIERS["main"]),
            ("com.apple.security.application-groups", []),
        ):
            with self.subTest(name=name), self.assertRaises(ValueError):
                profile = valid_profile("live")
                profile["Entitlements"][name] = value
                validator.validate_profile(plistlib.dumps(profile), "live")

    def test_empty_or_corrupt_input_fails_closed(self):
        for data in (b"", b"not a plist", b"<?xml version='1.0'?><broken>"):
            with self.subTest(data=data):
                with self.assertRaisesRegex(ValueError, "not a readable"):
                    validator.validate_profile(data)

    def test_non_dictionary_or_missing_entitlements_fails(self):
        for value in ([], {}, {"Entitlements": []}):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    validator.validate_profile(plistlib.dumps(value))

    def test_each_required_entitlement_is_enforced(self):
        invalid_values = {
            "application-identifier": ["OTHER.app.fyrup.ios", "6379AH75GK.other.app"],
            "com.apple.developer.healthkit": [False, "true", 1],
            "com.apple.developer.weatherkit": [False, "true", 1],
            "aps-environment": ["development", ""],
            "com.apple.developer.applesignin": [[], ["Other"], "Default"],
            "com.apple.security.application-groups": [[], ["group.other"], validator.APP_GROUP],
        }
        for name, values in invalid_values.items():
            for value in values:
                with self.subTest(name=name, value=value):
                    profile = valid_profile()
                    profile["Entitlements"][name] = value
                    with self.assertRaises(ValueError):
                        validator.validate_profile(plistlib.dumps(profile))

    def test_missing_entitlements_are_rejected_individually(self):
        for name in valid_profile()["Entitlements"]:
            with self.subTest(name=name):
                profile = valid_profile()
                del profile["Entitlements"][name]
                with self.assertRaises(ValueError):
                    validator.validate_profile(plistlib.dumps(profile))

    def test_invalid_pipe_exits_nonzero_without_success_message(self):
        profile = valid_profile()
        profile["Entitlements"]["aps-environment"] = "development"
        result = subprocess.run(
            [sys.executable, str(SCRIPT)], input=plistlib.dumps(profile),
            capture_output=True, check=False, timeout=10,
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"Production push missing", result.stderr)

    def test_unknown_target_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unknown signing target"):
            validator.validate_profile(plistlib.dumps(valid_profile()), "other")


if __name__ == "__main__":
    unittest.main()
