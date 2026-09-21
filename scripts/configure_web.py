import json
import re
from shutil import copyfile
from pathlib import Path


index_path = Path("web/index.html")
html = index_path.read_text(encoding="utf-8")
html = re.sub(
    r'<meta name="viewport"[^>]*>',
    '<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">',
    html,
    count=1,
)
html = re.sub(r"<title>.*?</title>", "<title>Baby Monitor</title>", html, count=1)

head_tags = [
    '<meta name="apple-mobile-web-app-capable" content="yes">',
    '<meta name="apple-mobile-web-app-status-bar-style" content="default">',
    '<meta name="apple-mobile-web-app-title" content="Baby Monitor">',
    '<meta name="description" content="تسجيل محلي تجريبي ومعلومات إرشادية لرعاية طفلك.">',
]
for tag in head_tags:
    if tag.split('"')[1] not in html:
        html = html.replace("</head>", f"  {tag}\n</head>")
apple_touch_icon = '<link rel="apple-touch-icon" href="icons/apple-touch-icon.png">'
if re.search(r'<link rel="apple-touch-icon"[^>]*>', html):
    html = re.sub(
        r'<link rel="apple-touch-icon"[^>]*>',
        apple_touch_icon,
        html,
        count=1,
    )
else:
    html = html.replace("</head>", f"  {apple_touch_icon}\n</head>")
index_path.write_text(html, encoding="utf-8")

web_icons = Path("web/icons")
web_icons.mkdir(parents=True, exist_ok=True)
copyfile(
    "assets/branding/baby_monitor_cartoon_icon_192.png",
    web_icons / "Icon-192.png",
)
copyfile(
    "assets/branding/baby_monitor_cartoon_icon_512.png",
    web_icons / "Icon-512.png",
)
copyfile(
    "assets/branding/baby_monitor_cartoon_icon_180.png",
    web_icons / "apple-touch-icon.png",
)
copyfile("assets/branding/baby_monitor_cartoon_icon_32.png", "web/favicon.png")

manifest_path = Path("web/manifest.json")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest.update(
    {
        "name": "Baby Monitor",
        "short_name": "Baby Monitor",
        "start_url": "./",
        "scope": "./",
        "display": "standalone",
        "orientation": "portrait",
        "background_color": "#fdfbff",
        "theme_color": "#fdfbff",
        "icons": [
            {
                "src": "icons/Icon-192.png",
                "sizes": "192x192",
                "type": "image/png",
            },
            {
                "src": "icons/Icon-512.png",
                "sizes": "512x512",
                "type": "image/png",
            },
        ],
    }
)
manifest_path.write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
