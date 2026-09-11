"""Bounded macOS-only reference QA, no archive, upload or automatic rerun."""
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def run(args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def select_simulator(available):
    """Use an installed iOS runtime; an Xcode version is not an iOS version.

    Both preferred phones have the 393 x 852 pt reference size. Never substitute
    a wider Pro Max, download a new runtime, or silently resize the resulting PNG.
    The pinned Xcode image and the actual chosen runtime are recorded separately.
    """
    devices = available.get("devicetypes", [])
    device = next((item for name in ("iPhone 16", "iPhone 15")
                   for item in devices if item.get("name") == name), None)
    if device is None:
        raise RuntimeError("No reference-size iPhone 16/15 device type installed; see simulator-inventory.json")
    def version(item):
        try:
            return tuple(int(part) for part in item.get("version", "0").split("."))
        except ValueError:
            return (0,)
    runtimes = [item for item in available.get("runtimes", [])
                if item.get("isAvailable") is True and item.get("name", "").startswith("iOS ") and version(item) >= (17,)]
    if not runtimes:
        raise RuntimeError("No installed available iOS 17+ runtime; see simulator-inventory.json")
    return device, max(runtimes, key=version)


def main():
    if sys.platform != "darwin":
        raise SystemExit("NOT RUN: iOS Simulator requires macOS.")
    output = Path("build/reference-qa")
    output.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    full = os.environ.get("FYRUP_QA_FULL_REGRESSION", "false").lower() == "true"
    followup = os.environ.get("FYRUP_QA_FOLLOWUP", "").strip().lower()
    if followup not in {"", "setup-summary", "redesign-regressions"}:
        raise SystemExit("Unsupported FYRUP_QA_FOLLOWUP value")
    summary = {"startedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
               "commit": run(["git", "rev-parse", "HEAD"], capture_output=True).stdout.strip(),
               "purpose": ("full-regression" if full else
                           "targeted setup-summary follow-up" if followup == "setup-summary" else
                           "targeted editorial regression follow-up" if followup == "redesign-regressions" else
                           "unit-suite, reference checkpoints and targeted live workout"),
               "xcode": run(["xcodebuild", "-version"], capture_output=True).stdout.strip(),
               "deviceTests": "NOT RUN", "status": "RUNNING", "automaticRetries": 0}
    device = None
    try:
        available = json.loads(run(["xcrun", "simctl", "list", "--json"], capture_output=True).stdout)
        (output / "simulator-inventory.json").write_text(json.dumps(available, indent=2), encoding="utf-8")
        device_type, runtime = select_simulator(available)
        device = run(["xcrun", "simctl", "create", "FYRUP Reference QA", device_type["identifier"], runtime["identifier"]], capture_output=True).stdout.strip()
        summary.update(deviceName=device_type["name"], runtime=runtime["name"], runtimeVersion=runtime["version"], simulator=device)
        print(json.dumps({"selectedDevice": device_type["name"], "selectedRuntime": runtime["name"]}), flush=True)
        run(["xcrun", "simctl", "boot", device])
        run(["xcrun", "simctl", "bootstatus", device, "-b"], timeout=180)
        run(["xcrun", "simctl", "status_bar", device, "override", "--time", "9:41", "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3", "--batteryState", "charged", "--batteryLevel", "100"])
        command = ["xcodebuild", "test", "-project", "FYRUP.xcodeproj", "-scheme", "FYRUP", "-configuration", "Debug",
                   "-destination", f"platform=iOS Simulator,id={device}", "-resultBundlePath", "build/FYRUP.xcresult",
                   "-parallel-testing-enabled", "NO", "-maximum-test-execution-time-allowance", "180",
                   "-test-timeouts-enabled", "YES", "CODE_SIGNING_ALLOWED=NO"]
        if followup == "setup-summary":
            command += ["-only-testing:FYRUPUITests/ReferenceCheckpointUITests/testNamedSetupChoicesAndEditableSummary"]
        elif followup == "redesign-regressions":
            command += [
                "-only-testing:FYRUPUITests/CriticalFlowsUITests/testTodayStartAndCompleteFlow",
                "-only-testing:FYRUPUITests/CriticalFlowsUITests/testPlanWorkoutFlow",
                "-only-testing:FYRUPUITests/CriticalFlowsUITests/testFriendsAndActivityDetailsNavigation",
                "-only-testing:FYRUPUITests/CriticalFlowsUITests/testSettingsDestinationsWork",
                "-only-testing:FYRUPUITests/CriticalFlowsUITests/testProfileSportsRemainEditable",
                "-only-testing:FYRUPUITests/ReferenceCheckpointUITests/testNamedSetupChoicesAndEditableSummary",
                "-only-testing:FYRUPUITests/StepFlowsUITests/testHealthIsOptionalAndNotNowKeepsTrainingAvailable",
                "-only-testing:FYRUPUITests/WorkoutFlowsUITests/testCreatePlanSurvivesRelaunchAndEasyTraining",
            ]
        elif not full:
            command += [
                "-only-testing:FYRUPTests",
                "-only-testing:FYRUPUITests/ReferenceCheckpointUITests",
                "-only-testing:FYRUPUITests/WorkoutFlowsUITests/testTrackOptionalSetValuesAndPause",
            ]
        # A single attempt. The external 20-minute checkpoint cap includes setup/cleanup.
        with (output / "xcodebuild.log").open("w", encoding="utf-8") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                result = process.wait(timeout=(50 if full else 17) * 60)
            except subprocess.TimeoutExpired:
                import signal
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                raise RuntimeError("QA time limit reached; inspect artifacts before any new run.")
        summary["status"] = "PASS" if result == 0 else "FAIL"
        if result:
            # Surface compiler/test failures, never dump environment or request payloads.
            for line in (output / "xcodebuild.log").read_text(encoding="utf-8", errors="replace").splitlines():
                if "error:" in line or "Test Case" in line and "failed" in line:
                    print(line[:1000])
    except Exception as error:
        summary["status"] = "FAIL"
        summary["failureType"] = type(error).__name__
        print(str(error)[:500])
    finally:
        if device:
            subprocess.run(["xcrun", "simctl", "shutdown", device], check=False)
            # Only this explicitly created disposable simulator, not all user devices.
            subprocess.run(["xcrun", "simctl", "delete", device], check=False)
        summary["elapsedMinutes"] = round((time.monotonic() - started) / 60, 2)
        summary["estimatedUSDIncludingVATForScriptOnly"] = round(summary["elapsedMinutes"] * 0.095 * 1.19, 2)
        summary["costNote"] = "Codemagic setup/checkout/publishing adds billed time; record the dashboard total separately."
        (output / "run.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
        print(json.dumps(summary, indent=2))
    return 0 if summary["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
