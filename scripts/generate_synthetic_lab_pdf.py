#!/usr/bin/env python3
"""Generate the Phase 1 synthetic HK-style women's panel PDF.

Run from repo root:
  python3 scripts/generate_synthetic_lab_pdf.py

Output: fixtures/labs/synthetic-hk-womens-panel.pdf
Golden extract rows live in fixtures/labs/synthetic-hk-womens-panel.extract.json
Keep PDF text layout stable — Phase 2 Edge Function tests against the golden fixture.
"""

from __future__ import annotations

from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "fixtures" / "labs" / "synthetic-hk-womens-panel.pdf"

# Rows must match fixtures/labs/synthetic-hk-womens-panel.extract.json
# Columns: Test | Result | Unit | Reference Range | Flag
BIOMARKER_ROWS: list[tuple[str, str, str, str, str]] = [
    ("FSH", "68.4", "IU/L", "Postmenopausal >25.8", "H"),
    ("LH", "42.1", "IU/L", "Postmenopausal 7.7–58.5", ""),
    ("Estradiol (E2)", "28", "pmol/L", "Postmenopausal <118", ""),
    ("TSH", "2.41", "mIU/L", "0.27–4.20", ""),
    ("Free T4", "14.8", "pmol/L", "12.0–22.0", ""),
    ("Vitamin D (25-OH)", "38", "nmol/L", "50–125", "L"),
    ("Calcium", "2.28", "mmol/L", "2.15–2.50", ""),
    ("Albumin", "42", "g/L", "35–52", ""),
    ("ALP", "98", "U/L", "35–105", ""),
    ("Glucose (fasting)", "5.6", "mmol/L", "3.9–5.6", ""),
    ("HbA1c", "5.8", "%", "<5.7", "H"),
    ("Total Cholesterol", "5.9", "mmol/L", "<5.2", "H"),
    ("LDL Cholesterol", "3.8", "mmol/L", "<2.6", "H"),
    ("HDL Cholesterol", "1.4", "mmol/L", ">1.0", ""),
    ("Triglycerides", "1.5", "mmol/L", "<1.7", ""),
    ("Haemoglobin", "128", "g/L", "115–150", ""),
    ("Ferritin", "45", "ug/L", "15–150", ""),
    ("CRP (hs)", "2.1", "mg/L", "<3.0", ""),
]


def build() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(OUT),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=16 * mm,
        bottomMargin=16 * mm,
        title="Synthetic HK Women's Health Panel — femm demo",
        author="femm prototype (fictional)",
    )

    styles = getSampleStyleSheet()
    title = ParagraphStyle(
        "TitleHK",
        parent=styles["Heading1"],
        fontSize=14,
        alignment=TA_CENTER,
        spaceAfter=4,
    )
    meta = ParagraphStyle(
        "Meta",
        parent=styles["Normal"],
        fontSize=9,
        leading=12,
        alignment=TA_LEFT,
        spaceAfter=2,
    )
    note = ParagraphStyle(
        "Note",
        parent=styles["Normal"],
        fontSize=8,
        leading=10,
        textColor=colors.HexColor("#444444"),
        spaceBefore=8,
    )

    story: list = []
    story.append(Paragraph("HarbourView Diagnostics (FICTIONAL)", title))
    story.append(
        Paragraph(
            "Women's Health Check — Comprehensive Laboratory Report",
            ParagraphStyle(
                "Sub",
                parent=styles["Normal"],
                fontSize=11,
                alignment=TA_CENTER,
                spaceAfter=10,
            ),
        )
    )
    story.append(Paragraph("<b>Patient Name:</b> CHAN Mei Ling (DEMO)", meta))
    story.append(Paragraph("<b>Sex / DOB:</b> Female / 15-Mar-1972", meta))
    story.append(Paragraph("<b>HKID (masked):</b> A123***(* )", meta))
    story.append(Paragraph("<b>Specimen Collected:</b> 2026-10-20 08:15 HKT", meta))
    story.append(Paragraph("<b>Report Issued:</b> 2026-10-20 16:40 HKT", meta))
    story.append(Paragraph("<b>Ordering Clinic:</b> Demo Central Medical Centre", meta))
    story.append(Paragraph("<b>Report ID:</b> FEMM-SYN-2026-001", meta))
    story.append(Spacer(1, 8 * mm))

    header = ["Test", "Result", "Unit", "Reference Range", "Flag"]
    data = [header] + [list(row) for row in BIOMARKER_ROWS]

    table = Table(data, colWidths=[48 * mm, 22 * mm, 22 * mm, 55 * mm, 14 * mm])
    table.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 8),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8EEF5")),
                ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#99AABB")),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("ALIGN", (1, 1), (2, -1), "RIGHT"),
                ("ALIGN", (4, 1), (4, -1), "CENTER"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                (
                    "ROWBACKGROUNDS",
                    (0, 1),
                    (-1, -1),
                    [colors.white, colors.HexColor("#F7F9FC")],
                ),
            ]
        )
    )
    story.append(table)
    story.append(
        Paragraph(
            "Flags: H = above reference range; L = below reference range when a "
            "numeric/qualitative reference is stated. This document is a "
            "<b>synthetic demo fixture</b> for the femm prototype — not a real "
            "patient report. Imaging findings (if any) are out of scope and must "
            "be ignored by extractors.",
            note,
        )
    )
    story.append(
        Paragraph(
            "Reference intervals are illustrative Hong Kong–style panel copy for "
            "prototype extract/match demos only. Not clinical advice.",
            note,
        )
    )

    doc.build(story)
    print(f"Wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    build()
