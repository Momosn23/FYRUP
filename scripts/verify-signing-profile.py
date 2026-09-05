"""Validate decoded Apple provisioning-profile bytes, including piped input."""

import plistlib
import sys


def validate_profile(data: bytes) -> None:
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
    checks = (
        (entitlements.get("application-identifier") == "6379AH75GK.app.fyrup.ios", "Unexpected signing target"),
        (entitlements.get("com.apple.developer.healthkit") is True, "HealthKit missing from profile"),
        (entitlements.get("aps-environment") == "production", "Production push missing"),
        (
            isinstance(entitlements.get("com.apple.developer.applesignin"), list)
            and "Default" in entitlements["com.apple.developer.applesignin"],
            "Apple sign-in missing",
        ),
    )
    for valid, message in checks:
        if not valid:
            raise ValueError(message)


def main() -> int:
    try:
        validate_profile(sys.stdin.buffer.read())
    except ValueError as error:
        print(f"Signing profile validation failed: {error}", file=sys.stderr)
        return 1
    print("Verified FYRUP profile: HealthKit, Apple sign-in and production push")
    return 0


if __name__ == "__main__":
    sys.exit(main())
