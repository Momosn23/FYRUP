"""Validate decoded Apple provisioning-profile bytes, including piped input."""

import plistlib
import sys


APP_GROUP = "group.app.fyrup.shared"
TARGET_IDENTIFIERS = {
    "main": "6379AH75GK.app.fyrup.ios",
    "live": "6379AH75GK.app.fyrup.ios.live",
}


def validate_profile(data: bytes, target: str = "main") -> None:
    # plistlib.load attempts to seek when detecting XML/binary formats. A shell
    # pipe cannot seek; loads safely detects the format from buffered bytes.
    try:
        profile = plistlib.loads(data)
    except Exception as error:
        raise ValueError("Profile data is not a readable Apple property list") from error
    if not isinstance(profile, dict):
        raise ValueError("Profile must be a dictionary")
    entitlements = profile.get("Entitlements")
    if not isinstance(entitlements, dict):
        raise ValueError("Profile entitlements are missing")
    if target not in TARGET_IDENTIFIERS:
        raise ValueError("Unknown signing target")
    groups = entitlements.get("com.apple.security.application-groups")
    checks = [
        (entitlements.get("application-identifier") == TARGET_IDENTIFIERS[target], "Unexpected signing target"),
        (isinstance(groups, list) and APP_GROUP in groups, "FYRUP App Group missing from profile"),
    ]
    if target == "main":
        checks.extend((
            (entitlements.get("com.apple.developer.healthkit") is True, "HealthKit missing from profile"),
            (entitlements.get("com.apple.developer.weatherkit") is True, "WeatherKit missing from profile"),
            (entitlements.get("aps-environment") == "production", "Production push missing"),
            (
                isinstance(entitlements.get("com.apple.developer.applesignin"), list)
                and "Default" in entitlements["com.apple.developer.applesignin"],
                "Apple sign-in missing",
            ),
        ))
    for valid, message in checks:
        if not valid:
            raise ValueError(message)


def main() -> int:
    try:
        if len(sys.argv) > 2:
            raise ValueError("Provide at most one signing target")
        target = sys.argv[1] if len(sys.argv) == 2 else "main"
        validate_profile(sys.stdin.buffer.read(), target)
    except ValueError as error:
        print(f"Signing profile validation failed: {error}", file=sys.stderr)
        return 1
    print(f"Verified FYRUP {target} profile and shared App Group")
    return 0


if __name__ == "__main__":
    sys.exit(main())
