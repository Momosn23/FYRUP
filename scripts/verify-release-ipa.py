"""Read-only validation of the actual IPA; never print backend credentials."""
import os
import plistlib
import re
import sys
import zipfile


def validate_ipa(path, expected_url, expected_key):
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
        backend = read_plist(app_root + "BackendConfig.plist")
        if backend.get("SUPABASE_URL") != expected_url:
            raise ValueError("Embedded backend URL does not match")
        if backend.get("SUPABASE_PUBLISHABLE_KEY") != expected_key:
            raise ValueError("Embedded backend key does not match")
        if backend.get("APP_ENVIRONMENT") != "production":
            raise ValueError("Release environment must be production")


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            raise ValueError("Provide exactly one IPA path")
        validate_ipa(sys.argv[1], os.environ.get("SUPABASE_URL"),
                     os.environ.get("SUPABASE_PUBLISHABLE_KEY"))
    except (ValueError, OSError, zipfile.BadZipFile) as error:
        print("Release validation failed: " + str(error), file=sys.stderr)
        sys.exit(1)
    print("Verified IPA: FYRUP bundle, both Health purposes and production backend")
