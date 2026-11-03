#!/usr/bin/env python3
"""Create plain-text, page-labelled copies of the PDFs in Rules/."""

from pathlib import Path
import re
import subprocess
import tempfile

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
    result = run_command([
        "pdftotext", "-layout", "-enc", "UTF-8", "-eol", "unix",
        str(pdf_path), "-",
    ])
    return result.stdout


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


def needs_ocr(pages):
    return any(len(re.sub(r"\s+", "", page)) < 20 for page in pages)


def clean_page(page):
    page = page.replace("\x00", "")
    page = re.sub(r"[ \t]+\n", "", page)
    page = re.sub(r"\n{4,}", "\n\n\n", page)
    return page.strip()


def run_ocr(pdf_path, output_path, force=False):
    mode = ["--force-ocr"] if force else ["--skip-text"]
    return run_command([
        "ocrmypdf", *mode, "--rotate-pages", "--deskew",
        "--language", "eng", "--jobs", "2",
        str(pdf_path), str(output_path),
    ])


def convert_pdf(pdf_path):
    page_count = get_page_count(pdf_path)
    original_pages = split_pages(extract_text(pdf_path), page_count)
    best_pages = original_pages
    extraction_method = "Existing PDF text layer"
    warnings = []

    if needs_ocr(original_pages):
        with tempfile.TemporaryDirectory(prefix="mage-knight-ocr-") as temp_dir:
            ocr_pdf = Path(temp_dir) / "searchable.pdf"
            try:
                run_ocr(pdf_path, ocr_pdf, force=False)
                ocr_pages = split_pages(extract_text(ocr_pdf), page_count)
                if text_size(ocr_pages) > text_size(best_pages):
                    best_pages = ocr_pages
                extraction_method = "PDF text extraction with OCR fallback for pages without a text layer"
            except subprocess.CalledProcessError as error:
                detail = (error.stderr or str(error)).strip().splitlines()
                warnings.append("OCR fallback failed: " + (detail[-1] if detail else "unknown OCR error"))

            # Some scans contain a minimal or unusable text layer on every page.
            # In that case, retry by rasterising the PDF and OCRing every page.
            if text_size(best_pages) < 50:
                forced_pdf = Path(temp_dir) / "forced-ocr.pdf"
                try:
                    run_ocr(pdf_path, forced_pdf, force=True)
                    forced_pages = split_pages(extract_text(forced_pdf), page_count)
                    if text_size(forced_pages) > text_size(best_pages):
                        best_pages = forced_pages
                        extraction_method = "Full-page OCR (PDF rasterised before text recognition)"
                except subprocess.CalledProcessError as error:
                    detail = (error.stderr or str(error)).strip().splitlines()
                    warnings.append("Full-page OCR failed: " + (detail[-1] if detail else "unknown OCR error"))

    low_text = text_size(best_pages) < 50
    if low_text:
        warnings.append("Very little text was extracted; compare this document with the original PDF.")

    output_lines = [
        f"SOURCE PDF: {pdf_path.relative_to(ROOT).as_posix()}",
        f"PAGE COUNT: {page_count}",
        f"EXTRACTION: {extraction_method}",
    ]
    if warnings:
        output_lines.append("REVIEW REQUIRED: " + " ".join(warnings))
    output_lines.extend([
        "NOTE: Original wording is retained. Page boundaries are labelled below. "
        "Visual-only material such as diagrams, maps, icons and images may not be represented.",
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
        "- Preserves extracted wording and reading order as provided by Poppler/Tesseract.",
        "- Uses layout-aware extraction to retain indentation and table alignment where possible.",
        "- Labels each page so rules can be traced back to the original PDF.",
        "- Uses OCR for pages without a usable embedded text layer; full-page OCR is a fallback for scan-only documents.",
        "",
        "Limitations:",
        "- OCR can misread small, decorative, rotated or low-resolution text.",
        "- Visual-only content (maps, diagrams, icons, illustrations and symbols) may not be captured.",
        "- Complex tables should be checked against the original PDF.",
        "- Files marked REVIEW REQUIRED need comparison with the original PDF.",
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
