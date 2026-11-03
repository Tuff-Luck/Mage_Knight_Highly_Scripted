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


def needs_ocr(pages):
    return any(len(re.sub(r"\s+", "", page)) < 20 for page in pages)


def clean_page(page):
    page = page.replace("\x00", "")
    page = re.sub(r"[ \t]+\n", "", page)
    page = re.sub(r"\n{4,}", "\n\n\n", page)
    return page.strip()


def convert_pdf(pdf_path):
    page_count = get_page_count(pdf_path)
    source_for_extraction = pdf_path
    initial_text = extract_text(pdf_path)
    pages = split_pages(initial_text, page_count)
    extraction_method = "Existing PDF text layer"

    if needs_ocr(pages):
        with tempfile.TemporaryDirectory(prefix="mage-knight-ocr-") as temp_dir:
            ocr_pdf = Path(temp_dir) / "searchable.pdf"
            run_command([
                "ocrmypdf", "--skip-text", "--rotate-pages", "--deskew",
                "--language", "eng", "--jobs", "2", str(pdf_path), str(ocr_pdf),
            ])
            ocr_text = extract_text(ocr_pdf)
            ocr_pages = split_pages(ocr_text, page_count)
            if sum(len(re.sub(r"\s+", "", page)) for page in ocr_pages) > sum(
                len(re.sub(r"\s+", "", page)) for page in pages
            ):
                pages = ocr_pages
            extraction_method = "PDF text extraction; OCR fallback applied to pages without a text layer"

    if sum(len(re.sub(r"\s+", "", page)) for page in pages) < 50:
        raise RuntimeError(
            f"Very little text could be extracted from {pdf_path.name}; "
            "review the PDF/OCR result rather than committing an empty conversion."
        )

    output_lines = [
        f"SOURCE PDF: {pdf_path.relative_to(ROOT).as_posix()}",
        f"PAGE COUNT: {page_count}",
        f"EXTRACTION: {extraction_method}",
        "NOTE: Original wording is retained. Page boundaries are labelled below. "
        "Visual-only material such as diagrams, maps, icons and images may not be represented.",
        "",
        "=" * 78,
        "",
    ]

    for page_number, page in enumerate(pages, start=1):
        output_lines.append(f"[PAGE {page_number:03d}]")
        text = clean_page(page)
        output_lines.append(
            text if text else "[No extractable text on this page.]"
        )
        output_lines.extend(["", ""])

    output_path = OUTPUT_DIR / f"{pdf_path.stem}.txt"
    output_path.write_text("\n".join(output_lines).rstrip() + "\n", encoding="utf-8")
    return output_path, page_count, extraction_method


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
        output_path, page_count, method = convert_pdf(pdf_path)
        results.append((pdf_path.name, output_path.name, page_count, method))
        print(f"Converted: {pdf_path.name} -> {output_path.relative_to(ROOT)} ({page_count} pages)")

    readme = [
        "MAGE KNIGHT RULES - AI-READABLE TEXT",
        "",
        "This folder contains plain UTF-8 text extractions of the PDF documents in ../.",
        "The original PDF files remain unchanged and are the visual source documents.",
        "",
        "Each text file:",
        "- Corresponds to the PDF with the same base filename.",
        "- Preserves the extracted wording and reading order as provided by Poppler.",
        "- Uses layout-aware extraction to retain indentation and table alignment where possible.",
        "- Labels each page so rules can be traced back to the original PDF.",
        "- Uses OCR for pages that do not contain a usable embedded text layer.",
        "",
        "Limitations:",
        "- OCR can misread small, decorative, rotated or low-resolution text.",
        "- Visual-only content (maps, diagrams, icons, illustrations and symbols) may not be captured.",
        "- Complex tables may need to be checked against the original PDF.",
        "- These files are transcriptions, not rewritten or interpreted rules.",
        "",
        "Converted PDFs:",
    ]
    for source_name, output_name, page_count, method in results:
        readme.append(f"- {source_name} -> {output_name} ({page_count} pages; {method})")
    (OUTPUT_DIR / "README.txt").write_text("\n".join(readme) + "\n", encoding="utf-8")

    print(f"\nCompleted {len(results)} PDF conversions.")


if __name__ == "__main__":
    main()
