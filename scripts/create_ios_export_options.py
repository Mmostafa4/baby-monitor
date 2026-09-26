from __future__ import annotations

import argparse
import os
from pathlib import Path
import plistlib
import re


def required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create the manual-signing export options for a TestFlight IPA."
    )
    parser.add_argument("--output", type=Path, default=Path("ios/ExportOptions.plist"))
    args = parser.parse_args()

    bundle_id = required_env("IOS_BUNDLE_ID")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle_id):
        raise SystemExit("IOS_BUNDLE_ID must be a reverse-DNS app identifier.")

    team_id = required_env("IOS_TEAM_ID")
    if not re.fullmatch(r"[A-Z0-9]{10}", team_id):
        raise SystemExit("IOS_TEAM_ID must be Apple's 10-character team identifier.")

    profile_name = required_env("IOS_PROFILE_NAME")
    options = {
        "method": "app-store-connect",
        "signingStyle": "manual",
        "teamID": team_id,
        "provisioningProfiles": {bundle_id: profile_name},
        "stripSwiftSymbols": True,
        "uploadSymbols": True,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("wb") as export_file:
        plistlib.dump(options, export_file, sort_keys=False)


if __name__ == "__main__":
    main()
