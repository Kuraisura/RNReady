#!/usr/bin/env python3
"""Fetch public-domain / CC-BY anatomy illustrations from Wikimedia Commons.

For each diagram id we try a list of candidate Commons file titles (best first)
and use the first that resolves. The Commons API rasterizes any source (incl.
SVG) to a PNG thumbnail at a fixed width, so output format + dimensions are
predictable, and `extmetadata` gives us the license + author for attribution.

Output:  assets/images/anatomy/<id>.png
Prints a Dart-ready summary (imageAspect + credit) for each id so the values can
be pasted into lib/features/anatomy/anatomy_data.dart.

Run:  dart run tool/fetch_anatomy_images.py   (or: python tool/fetch_anatomy_images.py)
Idempotent: skips ids whose PNG already exists.
"""

import json
import os
import re
import time
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = "RNReady/1.0 (educational nursing study app; contact: github.com/rn-ready)"
WIDTH = 1200  # rasterize width; height follows the source aspect
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "anatomy")

# diagram id -> candidate Commons file titles (without the "File:" prefix).
# First that resolves wins. Mostly SEER/Gray's (public domain) and a few
# OpenStax/Blausen (CC-BY) where no good PD plate exists.
CANDIDATES = {
    "heart": [
        "Diagram of the human heart (cropped).svg",
        "2007 Heart Anterior View.jpg",
        "Gray480.png",
    ],
    "neuron": [
        "Blausen 0657 MultipolarNeuron.png",
        "Complete neuron cell diagram en.svg",
        "Neuron.svg",
    ],
    "cell": [
        "Animal cell structure en.svg",
        "Biological cell.svg",
        "0312 Animal Cell and Components.jpg",
    ],
    "skin": [
        "Blausen 0810 SkinAnatomy 01.png",
        "Illu skin01.jpg",
        "508 Layers of the Skin.jpg",
    ],
    "long_bone": [
        "Illu long bone.jpg",
        "603 Anatomy of Long Bone.jpg",
        "Gray243.png",
    ],
    "eye": [
        "Three Main Layers of the Eye.png",
        "1413 Structure of the Eye.jpg",
        "Schematic diagram of the human eye en.svg",
    ],
    "respiratory": [
        "Illu conducting passages.jpg",
        "2306 Respiratory System.jpg",
    ],
    "digestive": [
        "Illu digestive system.svg",
        "Digestive system diagram en.svg",
        "2401 Components of the Digestive System.jpg",
    ],
    "nephron": [
        "Blausen 0708 Nephron Anatomy.png",
        "Physiology of Nephron.svg",
        "2618 Nephron Secretion Reabsorption.jpg",
    ],
    "heart_valves": [
        "2010 The Heart Valves.jpg",
        "Gray494.png",
        "Diagram of the human heart valves.svg",
    ],
    "blood_vessel": [
        "2102 Comparison of Artery and Vein.jpg",
        "Blausen 0055 ArteryWallStructure.png",
        "Illu artery.jpg",
    ],
    "urinary_system": [
        "Illu urinary system.jpg",
        "2605 The Urinary System.jpg",
    ],
    "kidney": [
        "Blausen 0592 KidneyAnatomy 01.png",
        "2610 The Kidney.jpg",
        "Gray1128.png",
    ],
    "fetal_skull": [
        "Gray197.png",
        "Neonate skull.png",
        "Fetal skull bones.svg",
    ],
}


def http_open(url, timeout=60):
    """GET with a polite User-Agent, retrying on HTTP 429 with backoff."""
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for attempt in range(6):
        try:
            return urllib.request.urlopen(req, timeout=timeout)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                retry_after = e.headers.get("Retry-After")
                wait = int(retry_after) if (retry_after or "").isdigit() \
                    else min(60, (2 ** attempt) * 3)
                print(f"    429 rate-limited; waiting {wait}s "
                      f"(attempt {attempt + 1}/6)")
                time.sleep(wait)
                continue
            raise
    raise RuntimeError("still rate-limited after retries")


def api_get(params):
    url = API + "?" + urllib.parse.urlencode(params)
    with http_open(url, timeout=30) as r:
        return json.load(r)


def resolve(title):
    """Return (thumburl, width, height, credit) for a title, or None."""
    data = api_get({
        "action": "query",
        "format": "json",
        "titles": "File:" + title,
        "prop": "imageinfo",
        "iiprop": "url|size|mime|extmetadata",
        "iiurlwidth": WIDTH,
    })
    pages = data.get("query", {}).get("pages", {})
    for _, page in pages.items():
        if "missing" in page:
            return None
        info = (page.get("imageinfo") or [None])[0]
        if not info or not info.get("thumburl"):
            return None
        meta = info.get("extmetadata", {})
        lic = (meta.get("LicenseShortName", {}) or {}).get("value", "")
        artist = (meta.get("Artist", {}) or {}).get("value", "")
        artist = re.sub("<[^>]+>", "", artist)  # strip HTML
        artist = re.sub(r"\s+", " ", artist).strip()  # collapse whitespace
        artist = re.split(r"\.\s|;", artist)[0].strip()  # drop trailing citation
        if len(artist) > 60:
            artist = artist[:57].rstrip() + "…"
        w = info.get("thumbwidth") or info.get("width")
        h = info.get("thumbheight") or info.get("height")
        credit = ", ".join(p for p in [artist, lic, "via Wikimedia Commons"] if p)
        return info["thumburl"], w, h, credit
    return None


def download(url, dest):
    with http_open(url, timeout=60) as r:
        data = r.read()
    with open(dest, "wb") as f:
        f.write(data)
    return len(data)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    summary = []
    for did, titles in CANDIDATES.items():
        dest = os.path.join(OUT_DIR, did + ".png")
        if os.path.exists(dest) and os.path.getsize(dest) > 0:
            print(f"= {did}: already present, skipping")
            summary.append((did, None, None, "(existing)"))
            continue
        got = None
        for t in titles:
            try:
                got = resolve(t)
            except Exception as e:
                print(f"  ! {did}: {t} -> error {e}")
                got = None
            if got:
                print(f"+ {did}: using '{t}'")
                break
            else:
                print(f"  - {did}: '{t}' not found, trying next")
        if not got:
            print(f"X {did}: NO candidate resolved -- add a title to CANDIDATES")
            continue
        url, w, h, credit = got
        try:
            size = download(url, dest)
        except Exception as e:
            print(f"X {did}: download failed -> {e}")
            continue
        aspect = round(w / h, 4) if w and h else 1.0
        print(f"  -> {size//1024} KB, {w}x{h}, aspect {aspect}, {credit}")
        summary.append((did, aspect, w and h, credit))
        time.sleep(2)  # be polite to Wikimedia between downloads

    print("\n# ---- paste into anatomy_data.dart ----")
    for did, aspect, _hw, credit in summary:
        if aspect is None:
            continue
        c = credit.replace("'", "\\'")
        print(f"// {did}: imageAsset: 'assets/images/anatomy/{did}.png', "
              f"imageAspect: {aspect}, credit: '{c}',")


if __name__ == "__main__":
    main()
