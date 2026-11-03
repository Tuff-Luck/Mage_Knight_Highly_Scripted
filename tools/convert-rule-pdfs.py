#!/usr/bin/env python3
"""Create page-labelled, single-flow AI-readable copies of the PDFs in Rules/."""

from pathlib import Path
import re
import subprocess
import tempfile
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
RULES_DIR = ROOT / "Rules"
OUTPUT_DIR = RULES_DIR / "AI-Text"


def run_command(args):
    return subprocess.run(
        args,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def get_page_count(pdf_path):
    result = run_command(["pdfinfo", str(pdf_path)])
    match = re.search(r"^Pages:\s+(\d+)\s*$", result.stdout, re.MULTILINE)
    if not match:
        raise RuntimeError(f"Could not determine page count for {pdf_path.name}")
    return int(match.group(1))


def extract_text(pdf_path):
    # -raw follows the PDF content stream instead of preserving page coordinates.
    # This avoids placing the left and right columns beside each other in the text.
    return run_command([
        "pdftotext", "-raw", "-enc", "UTF-8", "-eol", "unix",
        str(pdf_path), "-",
    ]).stdout


def split_pages(raw_text, expected_count):
    raw_text = raw_text.replace("\r\n", "\n").replace("\r", "\n")
    pages = raw_text.split("\f")
    if pages and not pages[-1].strip():
        pages.pop()
    pages = pages[:expected_count]
    pages.extend([""] * (expected_count - len(pages)))
    return [page.strip("\n") for page in pages]


def text_size(pages):
    return sum(len(re.sub(r"\s+", "", page)) for page in pages)


def bad_character_count(text):
    count = 0
    for char in text:
        category = unicodedata.category(char)
        if char == "\ufffd" or category == "Cc" and char not in "\n\t" or category == "Co":
            count += 1
    return count


def page_quality(page):
    visible = [char for char in page if not char.isspace()]
    if not visible:
        return 0.0
    bad = bad_character_count(page)
    letters = sum(char.isalpha() for char in visible)
    words = len(re.findall(r"[A-Za-z]{2,}", page))
    return (letters / len(visible)) - (bad / len(visible) * 8) + min(words / 500, 1) * 0.08


def pages_need_ocr(pages):
    return any(
        len(re.sub(r"\s+", "", page)) < 20
        or bad_character_count(page) > max(2, len(page) * 0.002)
        for page in pages
    )


def clean_page(page):
    page = page.replace("\x00", "").replace("\ufffd", " ")
    page = "".join(
        char for char in page
        if char in "\n\t" or unicodedata.category(char) not in {"Cc", "Cf"}
    )
    # Remove visual table-of-contents leader dots, not punctuation within prose.
    page = re.sub(r"[.·…]{4,}", " ", page)
    page = re.sub(r"[ \t]+", " ", page)
    page = re.sub(r" *\n *", "\n", page)
    page = re.sub(r"\n{3,}", "\n\n", page)
    return page.strip()


def run_ocr(pdf_path, output_path):
    return run_command([
        "ocrmypdf", "--force-ocr", "--rotate-pages", "--deskew",
        "--language", "eng", "--jobs", "2",
        str(pdf_path), str(output_path),
    ])


def convert_pdf(pdf_path):
    page_count = get_page_count(pdf_path)
    original_pages = split_pages(extract_text(pdf_path), page_count)
    best_pages = original_pages
    extraction_method = "PDF text extraction in content-stream reading order"
    warnings = []

    if pages_need_ocr(original_pages):
        with tempfile.TemporaryDirectory(prefix="mage-knight-ocr-") as temp_dir:
            ocr_pdf = Path(temp_dir) / "forced-ocr.pdf"
            try:
                run_ocr(pdf_path, ocr_pdf)
                ocr_pages = split_pages(extract_text(ocr_pdf), page_count)
                best_pages = [
                    ocr if page_quality(ocr) > page_quality(original) else original
                    for original, ocr in zip(original_pages, ocr_pages)
                ]
                extraction_method = "Content-stream text extraction with page-level OCR replacement for missing or corrupted text"
            except subprocess.CalledProcessError as error:
                detail = (error.stderr or str(error)).strip().splitlines()
                warnings.append("OCR fallback failed: " + (detail[-1] if detail else "unknown OCR error"))

    low_quality_pages = [
        number for number, page in enumerate(best_pages, start=1)
        if len(re.sub(r"\s+", "", page)) < 20
        or bad_character_count(page) > max(2, len(page) * 0.002)
    ]
    if low_quality_pages:
        warnings.append(
            "Text remains sparse or contains encoding artefacts on page(s): "
            + ", ".join(map(str, low_quality_pages))
            + ". Compare these pages with the original PDF."
        )

    output_lines = [
        f"SOURCE PDF: {pdf_path.relative_to(ROOT).as_posix()}",
        f"PAGE COUNT: {page_count}",
        f"EXTRACTION: {extraction_method}",
    ]
    if warnings:
        output_lines.append("REVIEW REQUIRED: " + " ".join(warnings))
    output_lines.extend([
        "NOTE: Original wording is retained. Each page is presented as a single text flow in reading order; page boundaries are labelled below. Visual-only material such as diagrams, maps, icons and images may not be represented.",
        "",
        "=" * 78,
        "",
    ])

    empty_pages = 0
    for page_number, page in enumerate(best_pages, start=1):
        output_lines.append(f"[PAGE {page_number:03d}]")
        text = clean_page(page)
        if text:
            output_lines.append(text)
        else:
            output_lines.append("[No extractable text on this page.]")
            empty_pages += 1
        output_lines.extend(["", ""])

    output_path = OUTPUT_DIR / f"{pdf_path.stem}.txt"
    output_path.write_text("\n".join(output_lines).rstrip() + "\n", encoding="utf-8")
    return output_path, page_count, extraction_method, warnings, empty_pages


def main():
    pdf_files = sorted(
        (path for path in RULES_DIR.glob("*.pdf") if path.is_file()),
        key=lambda path: path.name.casefold(),
    )
    if not pdf_files:
        raise RuntimeError(f"No PDF files found in {RULES_DIR}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    results = []

    for pdf_path in pdf_files:
        output_path, page_count, method, warnings, empty_pages = convert_pdf(pdf_path)
        results.append((pdf_path.name, output_path.name, page_count, method, warnings, empty_pages))
        status = "REVIEW" if warnings else "OK"
        print(f"[{status}] {pdf_path.name} -> {output_path.relative_to(ROOT)} "
              f"({page_count} pages; {empty_pages} pages without text)")
        for warning in warnings:
            print(f"  WARNING: {warning}")

    readme = [
        "MAGE KNIGHT RULES - AI-READABLE TEXT",
        "",
        "This folder contains plain UTF-8 text extractions of the PDF documents in ../.",
        "The original PDF files remain unchanged and are the visual source documents.",
        "",
        "Each text file:",
        "- Corresponds to the PDF with the same base filename.",
        "- Uses PDF content-stream reading order rather than fixed page coordinates, so multi-column pages become a single text flow (normally left column before right column).",
        "- Labels each page so rules can be traced back to the original PDF.",
        "- Uses OCR as a page-level replacement when embedded text is missing or has obvious encoding corruption.",
        "- Cleans control characters and decorative table-of-contents leader dots while preserving normal punctuation and wording.",
        "",
        "Limitations:",
        "- OCR can misread small, decorative, rotated or low-resolution text.",
        "- Visual-only content (maps, diagrams, icons, illustrations and symbols) may not be captured.",
        "- Complex tables should be checked against the original PDF.",
        "- Files marked REVIEW REQUIRED contain pages that remain sparse or have encoding artefacts.",
        "- These files are transcriptions, not rewritten or interpreted rules.",
        "",
        "Converted PDFs:",
    ]
    for source_name, output_name, page_count, method, warnings, empty_pages in results:
        status = "REVIEW REQUIRED" if warnings else "OK"
        readme.append(
            f"- {source_name} -> {output_name} ({page_count} pages; {status}; "
            f"{empty_pages} pages without extracted text; {method})"
        )
    (OUTPUT_DIR / "README.txt").write_text("\n".join(readme) + "\n", encoding="utf-8")

    print(f"\nCompleted {len(results)} PDF conversions.")


if __name__ == "__main__":
    main()
