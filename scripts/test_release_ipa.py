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

    def fixture(self, info_override=None, backend_override=None, fmt=plistlib.FMT_XML, extra_app=False, widget_override=None, missing_widget=False, signing=False, missing_signing=None):
        info = {"CFBundleIdentifier": "app.fyrup.ios",
                "NSHealthShareUsageDescription": "Read selected steps",
                "NSHealthUpdateUsageDescription": "No Health writes requested",
                "NSSupportsLiveActivities": True,
                "CFBundleURLTypes": [{"CFBundleURLSchemes": ["fyrup"]}],
                "CFBundleVersion": "11", "CFBundleShortVersionString": "1.0.0", "CFBundleExecutable": "FYRUP"}
        widget = {"CFBundleIdentifier": "app.fyrup.ios.live", "CFBundleVersion": "11",
                  "CFBundleShortVersionString": "1.0.0", "CFBundleExecutable": "FYRUPLive",
                  "NSExtension": {"NSExtensionPointIdentifier": "com.apple.widgetkit-extension"}}
        widget.update(widget_override or {})
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
            if not missing_widget:
                archive.writestr("Payload/FYRUP.app/PlugIns/FYRUPLive.appex/Info.plist", plistlib.dumps(widget, fmt=fmt))
            if extra_app:
                archive.writestr("Payload/Other.app/Info.plist", plistlib.dumps(info))
            if signing:
                components = {
                    "Payload/FYRUP.app/embedded.mobileprovision": b"profile-main",
                    "Payload/FYRUP.app/FYRUP": b"binary-main",
                    "Payload/FYRUP.app/PlugIns/FYRUPLive.appex/embedded.mobileprovision": b"profile-live",
                    "Payload/FYRUP.app/PlugIns/FYRUPLive.appex/FYRUPLive": b"binary-live",
                }
                for name, data in components.items():
                    if name != missing_signing:
                        archive.writestr(name, data)
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

    def test_rejects_missing_live_support_and_links(self):
        for field in [{"NSSupportsLiveActivities": False}, {"CFBundleURLTypes": []}, {"CFBundleURLTypes": "fyrup"}]:
            with self.assertRaisesRegex(ValueError, "Live Activit"):
                validator.validate_ipa(self.fixture(field), self.url, self.key)

    def test_rejects_missing_widget(self):
        with self.assertRaisesRegex(ValueError, "Missing"):
            validator.validate_ipa(self.fixture(missing_widget=True), self.url, self.key)

    def test_rejects_wrong_widget_and_mismatching_versions(self):
        for field in [{"CFBundleIdentifier": "other.widget"}, {"CFBundleVersion": "10"},
                      {"CFBundleShortVersionString": "2.0"}, {"NSExtension": {}}, {"NSExtension": "invalid"}]:
            with self.assertRaises(ValueError):
                validator.validate_ipa(self.fixture(widget_override=field), self.url, self.key)

    def entitlements(self, target):
        return {"application-identifier": validator.signing_profile.TARGET_IDENTIFIERS[target],
                "com.apple.security.application-groups": [validator.signing_profile.APP_GROUP],
                "com.apple.developer.weatherkit": True, "com.apple.developer.healthkit": True,
                "com.apple.developer.applesignin": ["Default"], "aps-environment": "production",
                "get-task-allow": False}

    def check_signing(self, archive=None, change_binary=None, change_profile=None):
        def profile_decoder(data):
            values = self.entitlements(data.decode().removeprefix("profile-"))
            values.update(change_profile or {})
            return plistlib.dumps({"Entitlements": values})

        def binary_reader(data):
            values = self.entitlements(data.decode().removeprefix("binary-"))
            values.update(change_binary or {})
            return values

        validator.validate_ipa(archive or self.fixture(signing=True), self.url, self.key,
                               profile_decoder=profile_decoder, entitlements_reader=binary_reader)

    def test_embedded_profiles_and_actual_binary_entitlements_are_both_checked(self):
        self.check_signing()
        for key, invalid in (("com.apple.developer.weatherkit", False), ("com.apple.developer.healthkit", False),
                             ("com.apple.security.application-groups", []), ("aps-environment", "development"),
                             ("com.apple.developer.applesignin", []), ("application-identifier", "WRONG")):
            for where in ("change_profile", "change_binary"):
                with self.subTest(key=key, where=where), self.assertRaises(ValueError):
                    self.check_signing(**{where: {key: invalid}})

    def test_store_profiles_and_executables_must_not_allow_debugging(self):
        for where in ("change_profile", "change_binary"):
            for invalid in (True, "false", 0):
                with self.subTest(where=where, value=invalid), self.assertRaisesRegex(ValueError, "debugging"):
                    self.check_signing(**{where: {"get-task-allow": invalid}})

    def test_missing_embedded_profile_or_executable_fails(self):
        for name in ("embedded.mobileprovision", "FYRUP", "PlugIns/FYRUPLive.appex/embedded.mobileprovision", "PlugIns/FYRUPLive.appex/FYRUPLive"):
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "signing component"):
                self.check_signing(self.fixture(signing=True, missing_signing="Payload/FYRUP.app/" + name))

    def test_executable_path_cannot_escape_archive_root(self):
        for name in ("../other", "/bin/other", "a\\b", "", "a/b"):
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "executable name"):
                self.check_signing(self.fixture(info_override={"CFBundleExecutable": name}, signing=True))

    def test_embedded_checks_cannot_be_partially_enabled(self):
        with self.assertRaisesRegex(ValueError, "Both embedded"):
            validator.validate_ipa(self.fixture(), self.url, self.key, profile_decoder=lambda data: data)


if __name__ == "__main__":
    unittest.main()
