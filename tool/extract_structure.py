"""Extract the section -> subtopic -> page-range structure from the bundled
nursing reviewer PDF and write it to assets/study/module_structure.json.

The reviewer encodes its outline visually:
  • Major sections  -> very large (size >= 20) headers ("NURSING PRACTICE I" ...)
  • Subtopics       -> a wide, short, COLOURED band behind the heading text.
                       Each section uses one dominant band colour (pink in NP I).

Run from the project root:  python tool/extract_structure.py
Requires: pymupdf  (pip install pymupdf)
"""
import json
import sys
from collections import Counter

import fitz  # PyMuPDF

PDF = "assets/modules/ackp_rn_nle_2025.pdf"
OUT = "assets/study/module_structure.json"
TEXT_OUT = "assets/study/subtopic_text.json"


def major_sections(doc):
    """Pages that start a major NURSING PRACTICE section (size >= 20 heading)."""
    out = {}
    for pno in range(doc.page_count):
        for blk in doc[pno].get_text("dict")["blocks"]:
            for line in blk.get("lines", []):
                for s in line.get("spans", []):
                    if s["size"] >= 20 and s["text"].strip():
                        out[pno + 1] = s["text"].strip()
    return out


def bands_on(page):
    """Coloured heading bands on a page -> list of (rgb_tuple, text)."""
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
            txt = page.get_textbox(r).strip().replace("\n", " ")
            txt = " ".join(txt.split())
            if txt and 2 < len(txt) < 60:
                out.append((rgb, txt))
    return out


def main():
    doc = fitz.open(PDF)
    n = doc.page_count
    majors = major_sections(doc)
    starts = sorted(majors)

    sections = []
    for i, start in enumerate(starts):
        end = (starts[i + 1] - 1) if i + 1 < len(starts) else n

        # Dominant band colour for this section = its subtopic marker.
        colour_counts = Counter()
        for pno in range(start - 1, end):
            for rgb, _ in bands_on(doc[pno]):
                colour_counts[rgb] += 1
        if not colour_counts:
            continue
        dominant = colour_counts.most_common(1)[0][0]

        # Collect subtopics in this section that use the dominant colour.
        raw = []
        seen = set()
        for pno in range(start - 1, end):
            for rgb, txt in bands_on(doc[pno]):
                if rgb == dominant and txt not in seen:
                    seen.add(txt)
                    raw.append((pno + 1, txt))

        # Compute each subtopic's end page (one before the next subtopic).
        subs = []
        for j, (pno, title) in enumerate(raw):
            sub_end = (raw[j + 1][0] - 1) if j + 1 < len(raw) else end
            subs.append({
                "title": title,
                "startPage": pno,
                "endPage": max(pno, sub_end),
            })

        r, g, b = (int(x * 255) for x in dominant)
        sections.append({
            "title": majors[start],
            "startPage": start,
            "endPage": end,
            "color": f"#{r:02x}{g:02x}{b:02x}",
            "subtopics": subs,
        })

    data = {
        "version": 1,
        "pdf": PDF,
        "pageCount": n,
        "sections": sections,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)

    # Also dump per-subtopic plain text (capped) for on-device AI quiz/case
    # generation, keyed by the subtopic's start page.
    text_by_page = {}
    for sec in sections:
        for sub in sec["subtopics"]:
            chunk = []
            for p in range(sub["startPage"] - 1, sub["endPage"]):
                chunk.append(doc[p].get_text())
            joined = " ".join(" ".join(chunk).split())
            text_by_page[str(sub["startPage"])] = joined[:2400]
    with open(TEXT_OUT, "w", encoding="utf-8") as f:
        json.dump({"version": 1, "text": text_by_page}, f, ensure_ascii=False)
    print(f"Wrote {TEXT_OUT}  ({len(text_by_page)} subtopic chunks)")

    total = sum(len(s["subtopics"]) for s in sections)
    print(f"Wrote {OUT}")
    print(f"  sections : {len(sections)}")
    print(f"  subtopics: {total}")
    for s in sections:
        print(f"  - {s['title']:<32} p{s['startPage']}-{s['endPage']}  "
              f"({len(s['subtopics'])} subtopics)  {s['color']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
