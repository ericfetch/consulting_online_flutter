"""Check the existing Apple app and allocate a separate iOS build number."""

import json
import os
from pathlib import Path
import re
import subprocess
import sys


def next_build_number(previous: str) -> str:
    # CFBundleVersion allows up to three numeric components (4 / 2 / 2 digits).
    if not re.fullmatch(r"[0-9]{1,4}(?:\.[0-9]{1,2}){0,2}", previous):
        raise ValueError(f"Unexpected TestFlight build number: {previous!r}")
    parts = [int(part) for part in previous.split(".")]
    if parts[0] < 1:
        raise ValueError("TestFlight build number must start with a positive integer")
    limits = [9999, 99, 99]
    for index in range(len(parts) - 1, -1, -1):
        if parts[index] < limits[index]:
            parts[index] += 1
            for suffix in range(index + 1, len(parts)):
                parts[suffix] = 0
            return ".".join(map(str, parts))
    if len(parts) < 3:
        return previous + ".1"
    raise ValueError("iOS build number is exhausted; choose a new numbering scheme")


def verify_app(payload: dict, app_id: str, bundle_id: str) -> None:
    app = payload.get("data", payload)
    if not isinstance(app, dict) or str(app.get("id")) != app_id:
        raise ValueError("App Store Connect returned a different App ID")
    actual_bundle = app.get("attributes", {}).get("bundleId")
    if actual_bundle != bundle_id:
        raise ValueError(
            f"Existing Apple app uses {actual_bundle!r}, but this project uses "
            f"{bundle_id!r}. Align with the existing app before building."
        )


def apple_cli(*arguments: str) -> str:
    # Never treat authentication/network failures as an empty App or build number.
    result = subprocess.run(
        ["app-store-connect", *arguments],
        check=True, capture_output=True, text=True, timeout=120,
    )
    return result.stdout.strip()


def main() -> None:
    app_id = os.environ["APP_STORE_APPLE_ID"]
    bundle_id = os.environ["BUNDLE_ID"]
    if not re.fullmatch(r"[0-9]+", app_id):
        raise ValueError("APP_STORE_APPLE_ID must be the numeric Apple App ID")
    project = Path("ios/Runner.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    project_ids = set(re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", project))
    expected_ids = {bundle_id, bundle_id + ".RunnerTests"}
    if not project_ids or project_ids - expected_ids or bundle_id not in project_ids:
        raise ValueError("BUNDLE_ID does not match the iOS Xcode project")

    verify_app(json.loads(apple_cli("apps", "get", app_id, "--json")), app_id, bundle_id)
    previous = apple_cli(
        "get-latest-testflight-build-number", app_id, "--platform", "IOS", "--all-versions",
    )
    build_number = next_build_number(previous)
    with Path(os.environ["CM_ENV"]).open("a", encoding="utf-8") as environment:
        environment.write(f"\nIOS_BUILD_NUMBER={build_number}\n")
    print(f"Verified App {app_id} ({bundle_id}); iOS build {previous} -> {build_number}")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError:
        sys.exit("Apple API request failed. Check the Codemagic integration, access and network; no build number was allocated.")
    except (ValueError, KeyError, OSError, subprocess.TimeoutExpired) as error:
        sys.exit(str(error))
