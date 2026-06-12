#!/usr/bin/env python3
"""Harvest clean, unlabeled anatomy candidates (mostly Servier Medical Art,
CC-BY 4.0) from Wikimedia Commons for review.

For each diagram id it runs one search to discover file titles, prefers Servier
results, then downloads the top few via Special:FilePath (one request each, no
API hit) into tool/preview/<id>/. We then view them and pick the keeper.

Heavily throttled — Commons rate-limits bursts aggressively.

Usage:  python tool/harvest_anatomy.py [id1 id2 ...]   (default: all)
"""

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://commons.wikimedia.org/w/api.php"
FILEPATH = "https://commons.wikimedia.org/wiki/Special:FilePath/"
UA = "RNReady/1.0 (educational nursing study app; github.com/rn-ready)"
PAUSE = 5  # seconds between every network call
PREVIEW = os.path.join(os.path.dirname(__file__), "preview")

QUERIES = {
    "heart": "heart Servier",
    "heart_valves": "heart valves Servier",
    "blood_vessel": "artery vein wall Servier",
    "neuron": "neuron nerve cell Servier",
    "skin": "skin integumentary Servier",
    "long_bone": "long bone structure Servier",
    "eye": "eye anatomy Servier",
    "respiratory": "lungs respiratory system Servier",
    "digestive": "digestive system Servier",
    "nephron": "nephron Servier",
    "urinary_system": "urinary system Servier",
    "kidney": "kidney anatomy Servier",
}


def _open(url, timeout=60):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for a in range(6):
        time.sleep(PAUSE)
        try:
            return urllib.request.urlopen(req, timeout=timeout)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                print(f"      429; backing off {6 * (a + 1)}s")
                time.sleep(6 * (a + 1))
                continue
            raise
    raise RuntimeError("rate-limited")


def search(q, n=8):
    url = API + "?" + urllib.parse.urlencode({
        "action": "query", "format": "json", "list": "search",
        "srsearch": q, "srnamespace": "6", "srlimit": n,
    })
    with _open(url, timeout=30) as r:
        d = json.load(r)
    bad = (".pdf", ".ogv", ".webm", ".ogg", ".djvu", ".tif", ".gif")
    titles = [s["title"] for s in d["query"]["search"]
              if not s["title"].lower().endswith(bad)]
    titles.sort(key=lambda t: 0 if "servier" in t.lower() else 1)
    return titles


def download(title, dest, width=1000):
    name = title.split("File:", 1)[-1]
    url = FILEPATH + urllib.parse.quote(name) + f"?width={width}"
    with _open(url) as r:
        data = r.read()
        ext = ".png" if "png" in r.headers.get("Content-Type", "") else \
            os.path.splitext(name)[1] or ".png"
    dest += ext
    with open(dest, "wb") as f:
        f.write(data)
    return dest, len(data)


def main():
    ids = sys.argv[1:] or list(QUERIES)
    for did in ids:
        q = QUERIES.get(did)
        if not q:
            print(f"X {did}: no query")
            continue
        outdir = os.path.join(PREVIEW, did)
        os.makedirs(outdir, exist_ok=True)
        print(f"\n# {did}: searching {q!r}")
        try:
            titles = search(q)
        except Exception as e:
            print(f"  search error: {e}")
            continue
        for i, t in enumerate(titles[:3]):
            try:
                dest, sz = download(t, os.path.join(outdir, f"{i:02d}"))
                print(f"  {i:02d}  {sz // 1024} KB  {dest}  <- {t}")
            except Exception as e:
                print(f"  {i:02d}  err {e}  <- {t}")


if __name__ == "__main__":
    main()
