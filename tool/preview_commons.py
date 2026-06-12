#!/usr/bin/env python3
"""Search Wikimedia Commons and download candidate thumbnails for review.

Used to find LABEL-FREE anatomy illustrations: run with a search query, it pulls
the top file results, downloads ~700px thumbnails into tool/preview/, and prints
an index. We then view them and pick the clean one.

Usage:  python tool/preview_commons.py "human heart unlabeled" heart
        (second arg = subfolder under tool/preview/)
"""

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = "RNReady/1.0 (educational nursing study app; github.com/rn-ready)"


def api(params):
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for a in range(6):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(3 * (a + 1))
                continue
            raise
    raise RuntimeError("rate-limited")


def search(q, n=8):
    d = api({
        "action": "query", "format": "json", "list": "search",
        "srsearch": q, "srnamespace": "6", "srlimit": n,
    })
    titles = [r["title"] for r in d["query"]["search"]]
    # Drop non-image media (PDFs, videos, audio).
    bad = (".pdf", ".ogv", ".webm", ".ogg", ".djvu", ".tif", ".gif")
    return [t for t in titles if not t.lower().endswith(bad)]


def thumb(title, w=700):
    d = api({
        "action": "query", "format": "json", "titles": title,
        "prop": "imageinfo", "iiprop": "url|size|mime", "iiurlwidth": w,
    })
    for _, p in d["query"]["pages"].items():
        ii = (p.get("imageinfo") or [None])[0]
        if ii and ii.get("thumburl"):
            return ii["thumburl"], ii.get("thumbwidth"), ii.get("thumbheight")
    return None


def download(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    with open(dest, "wb") as f:
        f.write(data)
    return len(data)


def main():
    q = sys.argv[1]
    sub = sys.argv[2] if len(sys.argv) > 2 else "misc"
    outdir = os.path.join(os.path.dirname(__file__), "preview", sub)
    os.makedirs(outdir, exist_ok=True)
    print(f"query: {q!r}  ->  {outdir}")
    for i, t in enumerate(search(q)):
        r = thumb(t)
        if not r:
            print(f"  {i:02d}  (no thumb)  {t}")
            continue
        url, w, h = r
        ext = os.path.splitext(urllib.parse.urlparse(url).path)[1] or ".png"
        dest = os.path.join(outdir, f"{i:02d}{ext}")
        try:
            download(url, dest)
        except Exception as e:
            print(f"  {i:02d}  dl-error {e}  {t}")
            continue
        print(f"  {i:02d}  {w}x{h}  {dest}  <-  {t}")
        time.sleep(1)


if __name__ == "__main__":
    main()
