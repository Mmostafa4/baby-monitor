from pathlib import Path
import plistlib


info_path = Path("ios/Runner/Info.plist")
with info_path.open("rb") as info_file:
    info = plistlib.load(info_file)

info["CFBundleDisplayName"] = "Baby Monitor"
info["NSMicrophoneUsageDescription"] = (
    "يُستخدم الميكروفون لتسجيل مقطع صوتي قصير بطلب منك. يبقى الصوت داخل التطبيق."
)
info["NSLocationWhenInUseUsageDescription"] = (
    "يُستخدم موقعك الحالي عند طلب البحث عن مستشفى أطفال قريب وبعد موافقتك."
)

with info_path.open("wb") as info_file:
    plistlib.dump(info, info_file, sort_keys=False)
