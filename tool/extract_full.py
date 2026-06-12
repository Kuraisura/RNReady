"""Re-extract the module outline with GUARANTEED full page coverage and full
(un-truncated) text, fixing the gaps in the original extract_structure.py.

Problems this fixes vs. the original:
  • Pages were skipped — e.g. page 1, and pages 501-512 — because subtopics were
    detected ONLY from the dominant coloured heading band. Headings in another
    style/colour were missed, and any page before the first detected heading in a
    section was left uncovered.
  • subtopic_text.json was capped at 2400 chars/subtopic, so multi-page topics
    were truncated and could never be "fully covered".

What this writes (all under assets/study/):
  • module_structure.json — sections -> subtopics, with EVERY page in a section
    belonging to exactly one subtopic (no gaps, page 1 onward).
  • page_text.json        — { "<page>": "<full text>" } for every page (no cap).
  • subtopic_text.json    — { "<startPage>": "<full range text>" } (no cap).

Run from the project root:
    pip install pymupdf
    python tool/extract_full.py
"""
import json
import os
import sys
from collections import Counter

import fitz  # PyMuPDF

PDF = "assets/modules/ackp_rn_nle_2025.pdf"
STRUCT_OUT = "assets/study/module_structure.json"
# Full per-page text is only needed for generation/verification, so keep it out
# of assets/ (not bundled into the app).
PAGE_OUT = "tool/page_text.json"
SUBTEXT_OUT = "assets/study/subtopic_text.json"
# Per-subtopic plain-text dump for deck authoring. NOT under assets/ so it is
# never bundled into the app — it only exists to be read during generation.
SRC_DIR = "tool/src_text"


def major_sections(doc):
    """Pages that start a major NURSING PRACTICE section (size >= 20 heading)."""
    out = {}
    for pno in range(doc.page_count):
        for blk in doc[pno].get_text("dict")["blocks"]:
            for line in blk.get("lines", []):
                for s in line.get("spans", []):
                    if s["size"] >= 20 and s["text"].strip():
                        out.setdefault(pno + 1, s["text"].strip())
    return out


def colour_bands(page):
    """Coloured heading bands on a page -> list of (rgb, text)."""
    W = page.rect.width
    out = []
    for dr in page.get_drawings():
        c = dr.get("fill")
        if not c:
            continue
        r = dr["rect"]
        if r.width > W * 0.40 and 6 < r.height < 40:
            rgb = tuple(round(x, 3) for x in c)
            if rgb == (1.0, 1.0, 1.0):
                continue
            txt = " ".join(page.get_textbox(r).split())
            if txt and 2 < len(txt) < 70:
                out.append((rgb, txt))
    return out


def main():
    doc = fitz.open(PDF)
    n = doc.page_count
    majors = major_sections(doc)
    starts = sorted(majors)
    if not starts:
        print("No major section headings found.", file=sys.stderr)
        return 1
    # Section 1 must cover page 1 even if its heading sits on a later page.
    if starts[0] > 1:
        starts = [1] + starts
        majors.setdefault(1, majors[min(majors)])

    sections = []
    for i, start in enumerate(starts):
        end = (starts[i + 1] - 1) if i + 1 < len(starts) else n
        title = majors.get(start, f"Section {i + 1}")

        # Subtopics = headings on this section's DOMINANT coloured band (clean,
        # matches the printed outline). The dominant colour is this section's
        # subtopic marker.
        band_counts = Counter()
        for pno in range(start, end + 1):
            for rgb, _ in colour_bands(doc[pno - 1]):
                band_counts[rgb] += 1
        dominant = band_counts.most_common(1)[0][0] if band_counts else None

        first_page_of = {}
        for pno in range(start, end + 1):
            for rgb, txt in colour_bands(doc[pno - 1]):
                if dominant is not None and rgb != dominant:
                    continue
                key = txt.lower()
                if key == title.lower():
                    continue
                if key not in first_page_of:
                    first_page_of[key] = (pno, txt)

        # Order subtopics by the page they first appear on.
        ordered = sorted(first_page_of.values(), key=lambda t: t[0])

        # GUARANTEE coverage: the first subtopic must start at the section start
        # (captures page 1 and pages 501-512 that have no band heading).
        if not ordered or ordered[0][0] > start:
            ordered = [(start, "Overview")] + ordered

        subs = []
        for j, (pno, t) in enumerate(ordered):
            sub_end = (ordered[j + 1][0] - 1) if j + 1 < len(ordered) else end
            subs.append({
                "title": t,
                "startPage": pno,
                "endPage": max(pno, sub_end),
            })

        if dominant is not None:
            r, g, b = (int(x * 255) for x in dominant)
        else:
            r, g, b = 0x5E, 0xEA, 0xD4
        sections.append({
            "title": title,
            "startPage": start,
            "endPage": end,
            "color": f"#{r:02x}{g:02x}{b:02x}",
            "subtopics": subs,
        })

    # ── full per-page text (no cap) ──
    page_text = {str(p + 1): doc[p].get_text() for p in range(n)}

    # ── full per-subtopic text (no cap), concatenated over its page range ──
    sub_text = {}
    for sec in sections:
        for sub in sec["subtopics"]:
            chunk = [doc[p - 1].get_text()
                     for p in range(sub["startPage"], sub["endPage"] + 1)]
            sub_text[str(sub["startPage"])] = " ".join(" ".join(chunk).split())

    with open(STRUCT_OUT, "w", encoding="utf-8") as f:
        json.dump({"version": 2, "pdf": PDF, "pageCount": n,
                   "sections": sections}, f, ensure_ascii=False, indent=1)
    with open(PAGE_OUT, "w", encoding="utf-8") as f:
        json.dump({"version": 1, "text": page_text}, f, ensure_ascii=False)
    with open(SUBTEXT_OUT, "w", encoding="utf-8") as f:
        json.dump({"version": 2, "text": sub_text}, f, ensure_ascii=False)

    # Per-subtopic text files (one small, readable file each) + an index, so the
    # deck author can open exactly one subtopic at a time.
    os.makedirs(SRC_DIR, exist_ok=True)
    index = []
    for si, sec in enumerate(sections):
        for sub in sec["subtopics"]:
            sp = sub["startPage"]
            fname = f"{sp:04d}.txt"
            header = (f"SECTION: {sec['title']}\n"
                      f"SUBTOPIC: {sub['title']}\n"
                      f"PAGES: {sp}-{sub['endPage']}\n"
                      f"{'-' * 60}\n")
            with open(os.path.join(SRC_DIR, fname), "w", encoding="utf-8") as f:
                f.write(header + (sub_text.get(str(sp), "")))
            index.append({"section": sec["title"], "title": sub["title"],
                          "startPage": sp, "endPage": sub["endPage"],
                          "file": f"{SRC_DIR}/{fname}"})
    with open(os.path.join(SRC_DIR, "_index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=1)

    # ── coverage report: assert every page 1..n is in exactly one subtopic ──
    covered = Counter()
    for sec in sections:
        for sub in sec["subtopics"]:
            for p in range(sub["startPage"], sub["endPage"] + 1):
                covered[p] += 1
    gaps = [p for p in range(1, n + 1) if covered[p] == 0]
    overlaps = [p for p in range(1, n + 1) if covered[p] > 1]
    total = sum(len(s["subtopics"]) for s in sections)

    print(f"Wrote {STRUCT_OUT}, {PAGE_OUT}, {SUBTEXT_OUT}")
    print(f"  sections : {len(sections)}")
    print(f"  subtopics: {total}")
    for s in sections:
        print(f"  - {s['title']:<34} p{s['startPage']}-{s['endPage']}  "
              f"({len(s['subtopics'])} subtopics)")
    print(f"  pages covered: {n - len(gaps)}/{n}")
    if gaps:
        print(f"  !! GAP pages (in no subtopic): {gaps}")
    if overlaps:
        print(f"  .. pages in >1 subtopic (ok if intentional): {len(overlaps)}")
    if not gaps:
        print("  OK: every page belongs to a subtopic (page 1 onward).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
