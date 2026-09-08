"""Read-only validation of the actual IPA; never print backend credentials."""
import os
import importlib.util
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile
import zipfile

spec = importlib.util.spec_from_file_location("fyrup_signing_profile", Path(__file__).with_name("verify-signing-profile.py"))
signing_profile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(signing_profile)


def decode_embedded_profile(data):
    """Decode the embedded bytes, not the profile originally selected in CI."""
    result = subprocess.run(["security", "cms", "-D"], input=data,
                            capture_output=True, check=False, timeout=30)
    if result.returncode:
        raise ValueError("Embedded signing profile could not be decoded")
    return result.stdout


def read_binary_entitlements(data):
    # Only this one executable is written. Never extract arbitrary archive paths
    # or execute the binary. codesign reads its embedded entitlement blob.
    with tempfile.TemporaryDirectory(prefix="fyrup-signature-") as directory:
        binary = Path(directory) / "executable"
        binary.write_bytes(data)
        result = subprocess.run(["codesign", "--display", "--entitlements", "-", "--xml", str(binary)],
                                capture_output=True, check=False, timeout=30)
    if result.returncode:
        raise ValueError("Signed executable entitlements could not be read")
    try:
        value = plistlib.loads(result.stdout)
    except Exception as error:
        raise ValueError("Signed executable has invalid entitlements") from error
    if not isinstance(value, dict):
        raise ValueError("Signed executable entitlements must be a dictionary")
    return value


def validate_ipa(path, expected_url, expected_key, profile_decoder=None, entitlements_reader=None):
    if not expected_url or not expected_key:
        raise ValueError("Expected backend configuration is missing")
    with zipfile.ZipFile(path) as archive:
        candidates = [item for item in archive.infolist()
                      if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", item.filename)]
        if len(candidates) != 1:
            raise ValueError("Expected exactly one app Info.plist")
        app_root = candidates[0].filename.removesuffix("Info.plist")

        def read_plist(name):
            items = [item for item in archive.infolist() if item.filename == name]
            if len(items) != 1 or items[0].file_size > 65536:
                raise ValueError("Missing, duplicated or oversized app configuration")
            try:
                value = plistlib.loads(archive.read(items[0]))
            except Exception as error:
                raise ValueError("Invalid app property list") from error
            if not isinstance(value, dict):
                raise ValueError("App property list must be a dictionary")
            return value

        info = read_plist(app_root + "Info.plist")
        if info.get("CFBundleIdentifier") != "app.fyrup.ios":
            raise ValueError("Unexpected app bundle identifier")
        for name in ("NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"):
            value = info.get(name)
            if not isinstance(value, str) or not value.strip():
                raise ValueError("Missing Health purpose string: " + name)
        if info.get("NSSupportsLiveActivities") is not True:
            raise ValueError("Live Activities support is missing")
        url_types = info.get("CFBundleURLTypes", [])
        if not isinstance(url_types, list) or not any(
                isinstance(item, dict) and isinstance(item.get("CFBundleURLSchemes"), list)
                and "fyrup" in item["CFBundleURLSchemes"] for item in url_types):
            raise ValueError("Live Activity return link is missing")
        widget = read_plist(app_root + "PlugIns/FYRUPLive.appex/Info.plist")
        if widget.get("CFBundleIdentifier") != "app.fyrup.ios.live":
            raise ValueError("Unexpected Live Activity extension identifier")
        for key in ("CFBundleVersion", "CFBundleShortVersionString"):
            if not isinstance(info.get(key), str) or not info[key] or widget.get(key) != info[key]:
                raise ValueError("App and Live Activity extension versions differ")
        extension = widget.get("NSExtension")
        if not isinstance(extension, dict) or extension.get("NSExtensionPointIdentifier") != "com.apple.widgetkit-extension":
            raise ValueError("Live Activity widget extension point is missing")
        backend = read_plist(app_root + "BackendConfig.plist")
        if backend.get("SUPABASE_URL") != expected_url:
            raise ValueError("Embedded backend URL does not match")
        if backend.get("SUPABASE_PUBLISHABLE_KEY") != expected_key:
            raise ValueError("Embedded backend key does not match")
        if backend.get("APP_ENVIRONMENT") != "production":
            raise ValueError("Release environment must be production")
        if (profile_decoder is None) != (entitlements_reader is None):
            raise ValueError("Both embedded signing checks are required together")
        if profile_decoder is not None:
            for target, root, target_info in (("main", app_root, info), ("live", app_root + "PlugIns/FYRUPLive.appex/", widget)):
                validate_embedded_signing(archive, root, target_info, target, profile_decoder, entitlements_reader)


def validate_embedded_signing(archive, root, info, target, profile_decoder, entitlements_reader):
    def read_unique(name, max_size):
        items = [item for item in archive.infolist() if item.filename == name]
        if len(items) != 1 or items[0].file_size == 0 or items[0].file_size > max_size:
            raise ValueError("Missing, duplicated or oversized embedded signing component")
        return archive.read(items[0])

    profile_data = profile_decoder(read_unique(root + "embedded.mobileprovision", 2 * 1024 * 1024))
    signing_profile.validate_profile(profile_data, target)
    executable = info.get("CFBundleExecutable")
    if not isinstance(executable, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", executable):
        raise ValueError("Invalid embedded executable name")
    actual = entitlements_reader(read_unique(root + executable, 256 * 1024 * 1024))
    if not isinstance(actual, dict):
        raise ValueError("Signed executable entitlements must be a dictionary")
    signing_profile.validate_profile(plistlib.dumps({"Entitlements": actual}), target)
    profile = plistlib.loads(profile_data)["Entitlements"]
    for entitlements in (profile, actual):
        if entitlements.get("get-task-allow") is not False:
            raise ValueError("Store signing must not permit debugging")


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            raise ValueError("Provide exactly one IPA path")
        validate_ipa(sys.argv[1], os.environ.get("SUPABASE_URL"),
                     os.environ.get("SUPABASE_PUBLISHABLE_KEY"),
                     profile_decoder=decode_embedded_profile, entitlements_reader=read_binary_entitlements)
    except (ValueError, OSError, zipfile.BadZipFile, subprocess.TimeoutExpired) as error:
        print("Release validation failed: " + str(error), file=sys.stderr)
        sys.exit(1)
    print("Verified IPA: FYRUP, Live Activity, matching versions, production backend, embedded profiles and signed WeatherKit/HealthKit/App Group entitlements")
