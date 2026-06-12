#!/usr/bin/env python3
"""Pull clean, unlabeled anatomy art from the SMART-Servier Medical Art
collection on Wikimedia Commons (CC-BY 4.0) for review.

Lists files straight from each Servier category (reliable titles), filters by
keyword per diagram, and downloads thumbnails via Special:FilePath into
tool/preview/<id>/ so we can view and pick the keeper.

Usage:  python tool/servier.py [id ...]      (default: all)
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
PAUSE = 4
PREVIEW = os.path.join(os.path.dirname(__file__), "preview")
CAT = "Category:SMART-Servier Medical Art - "

# id -> (servier subcategory, [title keywords])
PLAN = {
    "heart_valves": ("Cardiovascular system", ["valve"]),
    "blood_vessel": ("Cardiovascular system", ["artery", "vein", "vessel"]),
    "neuron": ("Nervous system", ["neuron", "nerve cell", "nerve "]),
    "skin": ("Dermatology", ["skin", "epidermis", "integument"]),
    "long_bone": ("Skeleton and bones", ["long bone", "bone structure", "bone "]),
    "eye": ("Ophthalmology", ["eye", "eyeball", "ocular"]),
    "respiratory": ("Respiratory system", ["lung", "respiratory", "trachea", "bronch"]),
    "digestive": ("Digestive system", ["digestive", "git ", "gastrointestinal", "stomach"]),
    "nephron": ("Urinary system", ["nephron"]),
    "urinary_system": ("Urinary system", ["urinary", "bladder", "ureter"]),
    "kidney": ("Urinary system", ["kidney"]),
}


def _open(url, timeout=60):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for a in range(6):
        time.sleep(PAUSE)
        try:
            return urllib.request.urlopen(req, timeout=timeout)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                time.sleep(6 * (a + 1))
                continue
            raise
    raise RuntimeError("rate-limited")


_cat_cache = {}


def cat_files(subcat):
    if subcat in _cat_cache:
        return _cat_cache[subcat]
    files, cont = [], None
    while True:
        params = {
            "action": "query", "format": "json", "list": "categorymembers",
            "cmtitle": CAT + subcat, "cmtype": "file", "cmlimit": "500",
        }
        if cont:
            params["cmcontinue"] = cont
        url = API + "?" + urllib.parse.urlencode(params)
        with _open(url, timeout=30) as r:
            d = json.load(r)
        files += [m["title"] for m in d["query"]["categorymembers"]]
        cont = d.get("continue", {}).get("cmcontinue")
        if not cont:
            break
    _cat_cache[subcat] = files
    return files


def download(title, dest, width=1000):
    name = title.split("File:", 1)[-1]
    url = FILEPATH + urllib.parse.quote(name) + f"?width={width}"
    with _open(url) as r:
        data = r.read()
    with open(dest + ".png", "wb") as f:
        f.write(data)
    return len(data)


def main():
    ids = sys.argv[1:] or list(PLAN)
    for did in ids:
        subcat, kws = PLAN[did]
        outdir = os.path.join(PREVIEW, did)
        os.makedirs(outdir, exist_ok=True)
        print(f"\n# {did}: category {subcat!r} keywords {kws}", flush=True)
        files = cat_files(subcat)
        matches = [t for t in files
                   if any(k.lower() in t.lower() for k in kws)
                   and not t.lower().endswith((".svg", ".pdf", ".tif", ".gif"))]
        print(f"  {len(matches)} matches", flush=True)
        for i, t in enumerate(matches[:5]):
            try:
                sz = download(t, os.path.join(outdir, f"s{i:02d}"))
                print(f"  s{i:02d}  {sz // 1024} KB  <- {t}", flush=True)
            except Exception as e:
                print(f"  s{i:02d}  err {e}  <- {t}", flush=True)


if __name__ == "__main__":
    main()
