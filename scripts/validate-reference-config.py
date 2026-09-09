"""Read-only milestone config checks; no secrets or backend requests."""
from pathlib import Path
import plistlib
import sys

sys.path.insert(0, str(Path(".qa/reference-tools").resolve()))
import yaml

root = Path(__file__).resolve().parent.parent
workflows = yaml.safe_load((root / "codemagic.yaml").read_text(encoding="utf-8"))["workflows"]
qa = workflows["ios-cloud-validation"]
full = workflows["ios-full-regression"]
release = workflows["ios-testflight"]
assert qa["triggering"]["events"] == [] and full["triggering"]["events"] == []
assert qa["triggering"]["cancel_previous_builds"] is True
assert qa["max_build_duration"] == 20 and full["max_build_duration"] == 60
assert release["max_build_duration"] == 9
assert release["inputs"]["runTests"]["default"] is False
assert qa["environment"]["vars"]["FYRUP_QA_FULL_REGRESSION"] == "false"
assert full["environment"]["vars"]["FYRUP_QA_FULL_REGRESSION"] == "true"
assert all(w["environment"]["xcode"] == "26.6" for w in workflows.values())
assert all("DerivedData" not in str(w.get("cache", {})) for w in workflows.values())
assert "fyrup_app_store_weatherkit" in [p["profile"] for p in release["environment"]["ios_signing"]["provisioning_profiles"]]
with (root / "FYRUP/FYRUP.entitlements").open("rb") as file:
    entitlements = plistlib.load(file)
assert entitlements["com.apple.developer.weatherkit"] is True
assert entitlements["com.apple.developer.healthkit"] is True
assert "group.app.fyrup.shared" in entitlements["com.apple.security.application-groups"]
project = yaml.safe_load((root / "project.yml").read_text(encoding="utf-8"))
assert project["options"]["xcodeVersion"] == "26.6"
print("PASS: parsed YAML, manual QA limits, Xcode pin, separate release profile and retained capabilities")
