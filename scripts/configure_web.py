import json
import re
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
    '<link rel="apple-touch-icon" href="icons/Icon-192.png">',
]
for tag in head_tags:
    if tag.split('"')[1] not in html:
        html = html.replace("</head>", f"  {tag}\n</head>")
index_path.write_text(html, encoding="utf-8")

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
    }
)
manifest_path.write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
