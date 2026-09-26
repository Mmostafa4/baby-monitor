from __future__ import annotations

import os
from pathlib import Path
import plistlib
import re


def _setting_value(value: str) -> str:
    if "\n" in value or "\r" in value:
        raise ValueError("Xcode signing values must be single-line strings.")
    if re.fullmatch(r"[A-Za-z0-9_.$()/-]+", value):
        return value
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _set_build_setting(settings: str, key: str, value: str) -> str:
    rendered = _setting_value(value)
    key_expression = rf'(?:{re.escape(key)}|"{re.escape(key)}")'
    rendered_key = f'"{key}"' if "[" in key else _setting_value(key)
    pattern = re.compile(rf"^([ \t]*){key_expression} = .*?;$", re.MULTILINE)
    replacement = rf"\g<1>{rendered_key} = {rendered};"
    updated, count = pattern.subn(replacement, settings, count=1)
    if count:
        return updated
    return settings.rstrip() + f"\n\t\t\t\t{rendered_key} = {rendered};\n"


configuration_pattern = re.compile(
    r"(?P<prefix>\t\t[0-9A-F]+ /\* (?P<name>Debug|Release|Profile) \*/ = \{\n"
    r"\t\t\tisa = XCBuildConfiguration;\n.*?\t\t\tbuildSettings = \{\n)"
    r"(?P<settings>.*?)"
    r"(?P<suffix>\n\t\t\t\};\n\t\t\tname = (?P=name);\n\t\t\};)",
    re.DOTALL,
)


def main() -> None:
    bundle_id = os.getenv("IOS_BUNDLE_ID", "").strip()
    team_id = os.getenv("IOS_TEAM_ID", "").strip()
    profile_name = os.getenv("IOS_PROFILE_NAME", "").strip()

    if bundle_id and not re.fullmatch(
        r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle_id
    ):
        raise ValueError("IOS_BUNDLE_ID must be a reverse-DNS app identifier.")
    if team_id and not re.fullmatch(r"[A-Z0-9]{10}", team_id):
        raise ValueError("IOS_TEAM_ID must be Apple's 10-character team identifier.")
    if bool(team_id) != bool(profile_name):
        raise ValueError("IOS_TEAM_ID and IOS_PROFILE_NAME must be set together.")

    info_path = Path("ios/Runner/Info.plist")
    with info_path.open("rb") as info_file:
        info = plistlib.load(info_file)
    info["CFBundleDisplayName"] = "Baby Monitor"
    info["NSMicrophoneUsageDescription"] = (
        "يُستخدم الميكروفون لتسجيل مقطع صوتي قصير بطلب منك. يبقى على الجهاز ما لم تختاري صراحةً إرساله للتحليل التجريبي."
    )
    info["NSLocationWhenInUseUsageDescription"] = (
        "يُستخدم موقعك الحالي عند طلب البحث عن مستشفى أطفال قريب وبعد موافقتك."
    )

    podfile_path = Path("ios/Podfile")
    podfile = None
    if podfile_path.exists():
        podfile, count = re.subn(
            r"platform :ios, ['\"][0-9.]+['\"]",
            "platform :ios, '15.0'",
            podfile_path.read_text(),
            count=1,
        )
        if count == 0:
            raise ValueError("Could not set the iOS deployment target in Podfile.")

    project_path = Path("ios/Runner.xcodeproj/project.pbxproj")
    project = project_path.read_text()
    project, deployment_count = re.subn(
        r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;",
        "IPHONEOS_DEPLOYMENT_TARGET = 15.0;",
        project,
    )
    if deployment_count == 0:
        raise ValueError("Could not set the iOS deployment target in Xcode project.")

    app_configurations = 0

    def update_runner_configuration(match: re.Match[str]) -> str:
        nonlocal app_configurations
        settings = match.group("settings")
        bundle_match = re.search(
            r"^[ \t]*PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);$",
            settings,
            re.MULTILINE,
        )
        if bundle_match is None or ".RunnerTests" in bundle_match.group(1):
            return match.group(0)

        app_configurations += 1
        name = match.group("name")
        if bundle_id:
            settings = _set_build_setting(
                settings, "PRODUCT_BUNDLE_IDENTIFIER", bundle_id
            )

        if name == "Release" and team_id and profile_name:
            settings = _set_build_setting(settings, "CODE_SIGN_STYLE", "Manual")
            settings = _set_build_setting(
                settings, "CODE_SIGN_IDENTITY[sdk=iphoneos*]", "Apple Distribution"
            )
            settings = _set_build_setting(settings, "DEVELOPMENT_TEAM", team_id)
            settings = _set_build_setting(
                settings, "PROVISIONING_PROFILE_SPECIFIER", profile_name
            )

        return match.group("prefix") + settings + match.group("suffix")

    project, updated_configs = configuration_pattern.subn(
        update_runner_configuration, project
    )
    if updated_configs == 0 or app_configurations == 0:
        raise ValueError("Could not find the iOS app build settings in Xcode project.")

    with info_path.open("wb") as info_file:
        plistlib.dump(info, info_file, sort_keys=False)
    if podfile is not None:
        podfile_path.write_text(podfile)
    project_path.write_text(project)


if __name__ == "__main__":
    main()
