"""Generate per-subtopic study slide decks with the CLAUDE API and write one file
per subtopic to assets/study/slides/<startPage>.json (the format the Flutter
ModuleSlidesScreen loads on demand).

Source content is the full, un-truncated per-subtopic text produced by
tool/extract_full.py (tool/src_text/<page>.txt + tool/src_text/_index.json).
Each deck is grounded STRICTLY in that text.

Design goals:
  • Resumable — a subtopic whose <startPage>.json already exists is skipped, so
    you can stop/restart anytime (or resume after a rate limit).
  • Incremental — each deck is written to its own file immediately.
  • Rate-limit safe — 429/529 are retried with backoff, then the run stops
    cleanly so you can resume later.

Usage (from the project root):
    python tool/generate_slides.py                 # all missing decks
    python tool/generate_slides.py --limit 5       # only 5 new decks (smoke test)
    python tool/generate_slides.py --overwrite      # regenerate everything
    python tool/generate_slides.py --only 38        # just the subtopic at page 38
    python tool/generate_slides.py --model claude-opus-4-8

Keys / config are read from .env:
    ANTHROPIC_API_KEY   (required)
    ANTHROPIC_MODEL     (optional; default claude-sonnet-4-6)
    ANTHROPIC_BASE_URL  (optional; default https://api.anthropic.com — set this
                         if your key is for a gateway/proxy)
No third-party packages required (stdlib only).
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

INDEX = "tool/src_text/_index.json"
SLIDES_DIR = "assets/study/slides"
DEFAULT_MODEL = "claude-sonnet-4-6"
DEFAULT_BASE = "https://api.anthropic.com"


def load_env(path=".env"):
    env = {}
    if not os.path.exists(path):
        return env
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    return env


class RateLimited(Exception):
    """Raised on HTTP 429/529 so the caller can back off / resume later."""


def _post(url, headers, body, timeout=120):
    data = json.dumps(body).encode("utf-8")
    headers = {
        "User-Agent": "rn-ready-slidegen/1.0",
        "Content-Type": "application/json",
        **headers,
    }
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "ignore")[:400]
        if e.code in (429, 529):
            raise RateLimited(f"HTTP {e.code}: {detail}")
        raise RuntimeError(f"HTTP {e.code}: {detail}")


def call_claude(base, key, model, system, user, max_tokens):
    """One Messages API call → assistant text. Retries 429/529 with backoff."""
    url = f"{base.rstrip('/')}/v1/messages"
    headers = {"x-api-key": key, "anthropic-version": "2023-06-01"}
    body = {
        "model": model,
        "max_tokens": max_tokens,
        "temperature": 0.3,
        "system": system,
        "messages": [{"role": "user", "content": user}],
    }
    delay = 5
    for attempt in range(5):
        try:
            data = _post(url, headers, body)
            parts = [b.get("text", "") for b in data.get("content", [])
                     if b.get("type") == "text"]
            return "".join(parts)
        except RateLimited:
            if attempt == 4:
                raise
            time.sleep(delay)
            delay = min(delay * 2, 60)
    raise RateLimited("exhausted retries")


SYSTEM = """\
You are a nursing instructor building a concise, exam-ready STUDY SLIDE DECK for
one subtopic of a Philippine Nurse Licensure (PNLE/NCLEX) reviewer. You receive
the subtopic title and its SOURCE TEXT (extracted from the module).

Return ONLY one JSON object (no prose, no markdown fences) of this exact shape:

{"title":"<subtopic title>",
 "slides":[
   {"type":"title","heading":"<topic>","subtitle":"<one-line overview>"},
   {"type":"bullets","heading":"<section>","bullets":["concise point","..."]},
   {"type":"terms","heading":"Key Terms","terms":[{"term":"X","definition":"..."}]},
   {"type":"table","heading":"<title>","columns":["A","B"],"rows":[["..",".."]]},
   {"type":"summary","heading":"Key Takeaways","bullets":["...","..."]}
 ]}

Rules:
- Ground EVERY word strictly in the SOURCE TEXT. Never invent facts, numbers,
  drugs, or terms not supported by it. Ignore stray text that clearly belongs to
  a different topic (the extractor sometimes bleeds a sentence across pages).
- Be COMPREHENSIVE: cover every distinct concept, classification, value, dose,
  step and definition in the source. Use as many slides as needed.
- Be precise and straight to the point: short bullets, no filler, no repetition.
- Whenever the source lists items, comparisons, schedules, stages or columns,
  render them as a "table"; render definition lists as "terms".
- The FIRST slide must be type "title"; the LAST slide must be type "summary".
- Output must be a single valid JSON object."""


def read_source(path):
    """Read a tool/src_text/<page>.txt file and return the body after the header."""
    with open(path, encoding="utf-8") as f:
        raw = f.read()
    marker = "-" * 60
    idx = raw.find(marker)
    return raw[idx + len(marker):].strip() if idx != -1 else raw.strip()


def extract_json_object(reply):
    start = reply.find("{")
    end = reply.rfind("}")
    if start < 0 or end <= start:
        return None
    blob = reply[start:end + 1]
    try:
        return json.loads(blob)
    except json.JSONDecodeError:
        blob = re.sub(r",(\s*[}\]])", r"\1", blob)  # tolerate trailing commas
        try:
            return json.loads(blob)
        except json.JSONDecodeError:
            return None


def valid_deck(obj):
    return (isinstance(obj, dict)
            and isinstance(obj.get("slides"), list)
            and len(obj["slides"]) > 0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0,
                    help="max NEW decks to generate this run (0 = no limit)")
    ap.add_argument("--overwrite", action="store_true",
                    help="regenerate decks even if the file already exists")
    ap.add_argument("--only", type=int, default=0,
                    help="only generate the subtopic with this start page")
    ap.add_argument("--model", default="", help="override the Claude model")
    ap.add_argument("--max-tokens", type=int, default=8000)
    ap.add_argument("--sleep", type=float, default=1.0,
                    help="seconds between calls")
    args = ap.parse_args()

    env = load_env()
    key = env.get("ANTHROPIC_API_KEY", "")
    if not key or key.startswith("put_your"):
        print("No ANTHROPIC_API_KEY in .env. Add one and retry.", file=sys.stderr)
        return 1
    base = env.get("ANTHROPIC_BASE_URL", DEFAULT_BASE)
    model = args.model or env.get("ANTHROPIC_MODEL", DEFAULT_MODEL)
    print(f"Model: {model}   Endpoint: {base}")

    with open(INDEX, encoding="utf-8") as f:
        index = json.load(f)

    # Dedupe by start page; merge titles when several subtopics share a page.
    by_page = {}
    for e in index:
        sp = e["startPage"]
        if sp not in by_page:
            by_page[sp] = {"file": e["file"], "titles": [e["title"]],
                           "section": e["section"]}
        elif e["title"] not in by_page[sp]["titles"]:
            by_page[sp]["titles"].append(e["title"])

    os.makedirs(SLIDES_DIR, exist_ok=True)

    made = skipped = failed = 0
    for sp in sorted(by_page):
        if args.only and sp != args.only:
            continue
        out_path = os.path.join(SLIDES_DIR, f"{sp}.json")
        if os.path.exists(out_path) and not args.overwrite:
            skipped += 1
            continue

        info = by_page[sp]
        title = " & ".join(info["titles"])
        try:
            source = read_source(info["file"])
        except OSError:
            source = ""
        if not source:
            print(f"  · p{sp}  (no source text — skipped)")
            continue

        user = f"SUBTOPIC TITLE: {title}\n\nSOURCE TEXT:\n{source}"
        try:
            reply = call_claude(base, key, model, SYSTEM, user, args.max_tokens)
        except RateLimited:
            print("\nRate limit reached. Progress saved — run again later to "
                  "resume.")
            break
        except Exception as ex:  # noqa: BLE001 - report and continue
            failed += 1
            print(f"  ! p{sp}  {title[:44]}  -> {ex}")
            time.sleep(args.sleep)
            continue

        deck = extract_json_object(reply)
        if not valid_deck(deck):
            failed += 1
            print(f"  ! p{sp}  {title[:44]}  -> unparseable reply, skipped")
            time.sleep(args.sleep)
            continue

        deck["title"] = title  # keep the canonical title(s)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(deck, f, ensure_ascii=False, indent=2)
        made += 1
        print(f"  ✓ p{sp:<4} {title[:50]:<50} {len(deck['slides'])} slides")

        if args.limit and made >= args.limit:
            print(f"\nReached --limit {args.limit}.")
            break
        time.sleep(args.sleep)

    total = len([f for f in os.listdir(SLIDES_DIR) if f.endswith(".json")])
    print(f"\nDone. generated={made}  skipped(existing)={skipped}  "
          f"failed={failed}")
    print(f"Total decks on disk: {total} / {len(by_page)} subtopics")
    return 0


if __name__ == "__main__":
    sys.exit(main())
