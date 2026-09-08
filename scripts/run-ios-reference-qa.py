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


def main():
    if sys.platform != "darwin":
        raise SystemExit("NOT RUN: iOS Simulator requires macOS.")
    output = Path("build/reference-qa")
    output.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    full = os.environ.get("FYRUP_QA_FULL_REGRESSION", "false").lower() == "true"
    summary = {"startedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
               "commit": run(["git", "rev-parse", "HEAD"], capture_output=True).stdout.strip(),
               "purpose": "full-regression" if full else "A01/R05 first reference checkpoint",
               "xcode": run(["xcodebuild", "-version"], capture_output=True).stdout.strip(),
               "deviceTests": "NOT RUN", "status": "RUNNING", "automaticRetries": 0}
    device = None
    try:
        available = json.loads(run(["xcrun", "simctl", "list", "--json"], capture_output=True).stdout)
        # Device type is explicitly selected, never stretch a Pro Max screenshot.
        device_type = next(t for t in available["devicetypes"] if t["name"] == "iPhone 16")
        runtime = next(r for r in available["runtimes"] if r.get("isAvailable") and r["name"].startswith("iOS 26.6"))
        device = run(["xcrun", "simctl", "create", "FYRUP Reference QA", device_type["identifier"], runtime["identifier"]], capture_output=True).stdout.strip()
        summary.update(deviceName="iPhone 16", runtime=runtime["name"], simulator=device)
        run(["xcrun", "simctl", "boot", device])
        run(["xcrun", "simctl", "bootstatus", device, "-b"], timeout=180)
        run(["xcrun", "simctl", "status_bar", device, "override", "--time", "9:41", "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3", "--batteryState", "charged", "--batteryLevel", "100"])
        command = ["xcodebuild", "test", "-project", "FYRUP.xcodeproj", "-scheme", "FYRUP", "-configuration", "Debug",
                   "-destination", f"platform=iOS Simulator,id={device}", "-resultBundlePath", "build/FYRUP.xcresult",
                   "-parallel-testing-enabled", "NO", "-maximum-test-execution-time-allowance", "180",
                   "-test-timeouts-enabled", "YES", "CODE_SIGNING_ALLOWED=NO"]
        if not full:
            command += ["-only-testing:FYRUPTests", "-only-testing:FYRUPUITests/ReferenceCheckpointUITests"]
        # A single attempt. The external 30-minute job cap also covers setup/cleanup.
        with (output / "xcodebuild.log").open("w", encoding="utf-8") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                result = process.wait(timeout=(50 if full else 24) * 60)
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
