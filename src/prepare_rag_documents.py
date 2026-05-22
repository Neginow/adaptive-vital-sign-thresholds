from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from .config import PROCESSED_DIR, RAG_DOCUMENTS_DIR, ensure_data_directories
from .rag_utils import (
    find_project_text_files,
    infer_source_type,
    infer_title,
    infer_vital_sign,
    normalize_whitespace,
    relative_source_path,
    split_paragraphs,
    split_text_into_chunks,
)

LOGGER = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")


def _format_number(value: object) -> str:
    if value is None or pd.isna(value):
        return "unknown"
    if float(value).is_integer():
        return str(int(float(value)))
    return f"{float(value):.1f}"


def _load_summary_table() -> pd.DataFrame:
    summary_path = PROCESSED_DIR / "vital_signs_elderly_icu_summary.csv"
    demo_path = PROCESSED_DIR / "vital_signs_elderly_icu_summary_demo.csv"
    if summary_path.exists():
        return pd.read_csv(summary_path)
    if demo_path.exists():
        LOGGER.warning("Using demo summary because the BigQuery summary file is missing.")
        return pd.read_csv(demo_path)
    raise FileNotFoundError(
        "No summary file found. Run python -m src.bigquery_extract_mimic first or enable demo fallback explicitly."
    )


def _summary_row_to_document(row: pd.Series, doc_id: str) -> dict[str, object]:
    mean_value = float(row.get("mean", float("nan")))
    median_value = float(row.get("median", float("nan")))
    p75_value = float(row.get("p75", float("nan")))
    p90_value = float(row.get("p90", float("nan")))
    itemid = _format_number(row.get("itemid", ""))
    label = str(row.get("label", row.get("vital_sign", "Unknown")))
    unitname = str(row.get("unitname", ""))
    age_group = str(row.get("age_group", "Unknown"))
    time_window = str(row.get("time_window", "Unknown"))
    standard_low = _format_number(row.get("standard_low", ""))
    standard_high = _format_number(row.get("standard_high", ""))
    vital_sign = str(row.get("vital_sign", "Unknown"))

    text = (
        f"Population: ICU patients aged {age_group}. "
        f"Source type: MIMIC-IV statistical summary. "
        f"Vital sign: {vital_sign}. "
        f"Item ID: {itemid}. "
        f"Measurement label: {label}. "
        f"Time window: {time_window.replace('_', ' ')} after ICU admission. "
        f"Unit: {unitname}. "
        f"Mean: {mean_value:.1f}. "
        f"Median: {median_value:.1f}. "
        f"P75: {p75_value:.1f}. "
        f"P90: {p90_value:.1f}. "
        f"Standard low threshold: {standard_low}. "
        f"Standard high threshold: {standard_high}. "
        f"Observation: This summary describes the distribution of {vital_sign} in elderly ICU patients for this age group and time window. "
        f"Standard thresholds should be interpreted cautiously in the ICU context and compared with the observed MIMIC-IV distribution."
    )

    return {
        "doc_id": doc_id,
        "text": text,
        "source_file": str(PROCESSED_DIR / "vital_signs_elderly_icu_summary.csv"),
        "source_type": "mimic_stats",
        "vital_sign": vital_sign,
        "itemid": row.get("itemid", ""),
        "label": label,
        "unitname": unitname,
        "age_group": age_group,
        "time_window": time_window,
        "section": f"{vital_sign.lower().replace(' ', '_')}_summary",
        "title": f"{vital_sign} summary for {age_group} / {time_window}",
        "is_demo_data": bool(row.get("is_demo_data", False)),
    }


def _text_document_to_records(path: Path, text: str) -> list[dict[str, object]]:
    paragraphs = split_paragraphs(text)
    title = infer_title(path, text)
    source_type = infer_source_type(path, text)
    records: list[dict[str, object]] = []
    if not paragraphs:
        return records

    section_name = title
    paragraph_index = 0
    for paragraph in paragraphs:
        if paragraph.startswith("#"):
            section_name = normalize_whitespace(paragraph.lstrip("#")) or section_name
            continue
        for chunk in split_text_into_chunks(paragraph):
            paragraph_index += 1
            records.append(
                {
                    "doc_id": f"{path.stem}_{paragraph_index:04d}",
                    "text": chunk,
                    "source_file": relative_source_path(path),
                    "source_type": source_type,
                    "vital_sign": infer_vital_sign(chunk),
                    "itemid": "",
                    "label": "",
                    "unitname": "",
                    "age_group": "",
                    "time_window": "",
                    "section": section_name,
                    "title": title,
                    "is_demo_data": False,
                }
            )
    return records


def build_rag_documents() -> pd.DataFrame:
    ensure_data_directories()
    records: list[dict[str, object]] = []

    summary_df = _load_summary_table()
    for index, (_, row) in enumerate(summary_df.iterrows(), start=1):
        records.append(_summary_row_to_document(row, f"mimic_stats_{index:04d}"))

    for path in find_project_text_files():
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = path.read_text(encoding="latin-1")
        records.extend(_text_document_to_records(path, text))

    documents_df = pd.DataFrame(records)
    documents_df = documents_df.drop_duplicates(subset=["doc_id", "text"]).reset_index(drop=True)
    output_path = RAG_DOCUMENTS_DIR / "rag_documents.csv"
    documents_df.to_csv(output_path, index=False)
    LOGGER.info("Saved %s rag documents to %s", len(documents_df), output_path)
    return documents_df


def main() -> None:
    build_rag_documents()


if __name__ == "__main__":
    main()
