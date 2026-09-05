import importlib.util
import io
from pathlib import Path
import plistlib
import unittest
import zipfile

spec = importlib.util.spec_from_file_location("verify_release_ipa", Path(__file__).with_name("verify-release-ipa.py"))
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class ReleaseIPATests(unittest.TestCase):
    url = "https://fixture.supabase.co"
    key = "fixture-not-a-real-key"

    def fixture(self, info_override=None, backend_override=None, fmt=plistlib.FMT_XML, extra_app=False):
        info = {"CFBundleIdentifier": "app.fyrup.ios",
                "NSHealthShareUsageDescription": "Read selected steps",
                "NSHealthUpdateUsageDescription": "No Health writes requested"}
        backend = {"SUPABASE_URL": self.url, "SUPABASE_PUBLISHABLE_KEY": self.key,
                   "APP_ENVIRONMENT": "production"}
        for name, value in (info_override or {}).items():
            if value is None:
                info.pop(name, None)
            else:
                info[name] = value
        backend.update(backend_override or {})
        result = io.BytesIO()
        with zipfile.ZipFile(result, "w") as archive:
            archive.writestr("Payload/FYRUP.app/Info.plist", plistlib.dumps(info, fmt=fmt))
            archive.writestr("Payload/FYRUP.app/BackendConfig.plist", plistlib.dumps(backend, fmt=fmt))
            if extra_app:
                archive.writestr("Payload/Other.app/Info.plist", plistlib.dumps(info))
        result.seek(0)
        return result

    def test_xml_and_binary_app_plists(self):
        for fmt in (plistlib.FMT_XML, plistlib.FMT_BINARY):
            validator.validate_ipa(self.fixture(fmt=fmt), self.url, self.key)

    def test_missing_or_blank_health_purpose(self):
        for name in ("NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"):
            for value in (None, "", "  ", 123):
                with self.subTest(name=name, value=value), self.assertRaisesRegex(ValueError, "Missing Health purpose"):
                    validator.validate_ipa(self.fixture({name: value}), self.url, self.key)

    def test_wrong_bundle(self):
        with self.assertRaisesRegex(ValueError, "bundle identifier"):
            validator.validate_ipa(self.fixture({"CFBundleIdentifier": "other.app"}), self.url, self.key)

    def test_each_backend_mismatch_fails_independently(self):
        for name in ("SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY", "APP_ENVIRONMENT"):
            with self.subTest(name=name), self.assertRaises(ValueError) as raised:
                validator.validate_ipa(self.fixture(backend_override={name: "DO-NOT-PRINT-THIS"}), self.url, self.key)
            self.assertNotIn("DO-NOT-PRINT-THIS", str(raised.exception))

    def test_missing_expected_configuration(self):
        for url, key in ((None, self.key), (self.url, None), ("", "")):
            with self.assertRaisesRegex(ValueError, "Expected backend"):
                validator.validate_ipa(self.fixture(), url, key)

    def test_rejects_ambiguous_app_bundle(self):
        with self.assertRaisesRegex(ValueError, "exactly one"):
            validator.validate_ipa(self.fixture(extra_app=True), self.url, self.key)

    def test_rejects_invalid_archive(self):
        with self.assertRaises(zipfile.BadZipFile):
            validator.validate_ipa(io.BytesIO(b"not an IPA"), self.url, self.key)


if __name__ == "__main__":
    unittest.main()
