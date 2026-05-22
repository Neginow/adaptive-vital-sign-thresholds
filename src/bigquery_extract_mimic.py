from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

import db_dtypes  # noqa: F401
import pandas as pd
from google.cloud import bigquery

from .config import ALLOW_DEMO_FALLBACK, HOSP_DATASET, ICU_DATASET, PROJECT_ID, PROCESSED_DIR, ensure_data_directories
from .rag_utils import age_group_from_age, time_window_from_hours

LOGGER = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")

ELDERLY_LIMIT = 1000
EVENT_LIMIT = 100000

VITAL_SPECS: list[dict[str, Any]] = [
    {
        "vital_sign": "Heart Rate",
        "itemids": [220045],
        "standard_low": 60,
        "standard_high": 100,
        "unitname_hint": "bpm",
        "legacy_output": True,
    },
    {
        "vital_sign": "Respiratory Rate",
        "itemids": [220210],
        "standard_low": 12,
        "standard_high": 20,
        "unitname_hint": "breaths/min",
        "legacy_output": False,
    },
    {
        "vital_sign": "Systolic Blood Pressure",
        "itemids": [220050, 220179],
        "standard_low": 90,
        "standard_high": 140,
        "unitname_hint": "mmHg",
        "legacy_output": False,
    },
    {
        "vital_sign": "Diastolic Blood Pressure",
        "itemids": [220051, 220180],
        "standard_low": 60,
        "standard_high": 90,
        "unitname_hint": "mmHg",
        "legacy_output": False,
    },
    {
        "vital_sign": "MAP",
        "itemids": [220052, 220181],
        "standard_low": 65,
        "standard_high": None,
        "unitname_hint": "mmHg",
        "legacy_output": False,
    },
    {
        "vital_sign": "Temperature Celsius",
        "itemids": [223762],
        "standard_low": 36.0,
        "standard_high": 38.0,
        "unitname_hint": "°C",
        "legacy_output": False,
    },
    {
        "vital_sign": "Temperature Fahrenheit",
        "itemids": [223761],
        "standard_low": 96.8,
        "standard_high": 100.4,
        "unitname_hint": "°F",
        "legacy_output": False,
    },
]

SUPPORTED_SP02_LABELS = ["spo2", "oxygen saturation", "o2 saturation", "saturation"]
UNWANTED_SP02_TERMS = ["alarm", "limit", "sensor", "placement", "waveform", "care plan", "apache", "note"]


def build_client() -> bigquery.Client:
    return bigquery.Client(project=PROJECT_ID)


def check_bigquery_connection(client: bigquery.Client) -> None:
    client.query("SELECT 1 AS ok LIMIT 1").to_dataframe()


def _save_dataframe(df: pd.DataFrame, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(path, index=False)
    LOGGER.info("Saved %s rows to %s", len(df), path)


def _demo_summary_frame() -> pd.DataFrame:
    return pd.DataFrame(
        [
            {
                "vital_sign": "Heart Rate",
                "itemid": 220045,
                "label": "Heart Rate",
                "unitname": "bpm",
                "age_group": "75-84",
                "time_window": "first_24h",
                "count": 12,
                "mean": 104.0,
                "median": 101.0,
                "min": 72.0,
                "max": 138.0,
                "std": 18.4,
                "p5": 74.0,
                "p25": 88.0,
                "p50": 101.0,
                "p75": 114.0,
                "p90": 122.0,
                "percent_above_standard_high": 58.3,
                "percent_below_standard_low": 0.0,
                "standard_low": 60.0,
                "standard_high": 100.0,
                "is_demo_data": True,
            }
        ]
    )


def _demo_sample_frame() -> pd.DataFrame:
    return pd.DataFrame(
        [
            {
                "subject_id": 1,
                "hadm_id": 1,
                "stay_id": 1,
                "anchor_age": 82,
                "age_group": "75-84",
                "intime": "2026-01-01 00:00:00",
                "charttime": "2026-01-01 02:00:00",
                "hours_since_icu_admission": 2.0,
                "time_window": "first_6h",
                "vital_sign": "Heart Rate",
                "itemid": 220045,
                "label": "Heart Rate",
                "unitname": "bpm",
                "value": 104.0,
                "is_demo_data": True,
            }
        ]
    )


def extract_elderly_icu_stays(client: bigquery.Client) -> pd.DataFrame:
    query = f"""
    SELECT
      p.subject_id,
      p.gender,
      p.anchor_age,
      i.hadm_id,
      i.stay_id,
      i.intime,
      i.outtime,
      i.los
    FROM `{HOSP_DATASET}.patients` p
    JOIN `{ICU_DATASET}.icustays` i
      ON p.subject_id = i.subject_id
    WHERE p.anchor_age >= 65
    LIMIT {ELDERLY_LIMIT}
    """
    return client.query(query).to_dataframe()


def extract_icu_vital_items(client: bigquery.Client) -> pd.DataFrame:
    query = f"""
    SELECT
      itemid,
      label,
      abbreviation,
      category,
      unitname
    FROM `{ICU_DATASET}.d_items`
    WHERE LOWER(label) LIKE '%heart rate%'
       OR LOWER(label) LIKE '%spo2%'
       OR LOWER(label) LIKE '%o2 saturation%'
       OR LOWER(label) LIKE '%oxygen saturation%'
       OR LOWER(label) LIKE '%saturation%'
       OR LOWER(label) LIKE '%respiratory%'
       OR LOWER(label) LIKE '%blood pressure%'
       OR LOWER(label) LIKE '%temperature%'
       OR LOWER(label) LIKE '%map%'
    ORDER BY label
    """
    return client.query(query).to_dataframe()


def resolve_spo2_items(client: bigquery.Client) -> pd.DataFrame:
    query = f"""
    SELECT
      itemid,
      label,
      abbreviation,
      category,
      unitname
    FROM `{ICU_DATASET}.d_items`
    WHERE LOWER(label) LIKE '%spo2%'
       OR LOWER(label) LIKE '%o2 saturation%'
       OR LOWER(label) LIKE '%oxygen saturation%'
       OR LOWER(label) LIKE '%saturation%'
    ORDER BY label
    """
    candidates = client.query(query).to_dataframe()
    if candidates.empty:
        return candidates

    label_series = candidates["label"].astype(str).str.lower()
    mask = pd.Series(True, index=candidates.index)
    for term in UNWANTED_SP02_TERMS:
        mask &= ~label_series.str.contains(term, na=False)
    filtered = candidates[mask].copy()
    if filtered.empty:
        return candidates.iloc[0:0].copy()

    preferred = filtered[
        filtered["label"].astype(str).str.contains("oxygen saturation|spo2|saturation", case=False, regex=True, na=False)
    ].copy()
    return preferred if not preferred.empty else filtered


def _query_vital_rows(client: bigquery.Client, cohort_table: str, itemids: list[int], limit: int = EVENT_LIMIT) -> pd.DataFrame:
    itemid_list = ", ".join(str(int(itemid)) for itemid in sorted(set(itemids)))
    query = f"""
    WITH elderly_icu AS (
      SELECT
        p.subject_id,
        p.anchor_age,
        i.hadm_id,
        i.stay_id,
        i.intime,
        i.outtime
      FROM `{HOSP_DATASET}.patients` p
      JOIN `{ICU_DATASET}.icustays` i
        ON p.subject_id = i.subject_id
      WHERE p.anchor_age >= 65
      LIMIT {ELDERLY_LIMIT}
    )
    SELECT
      e.subject_id,
      e.hadm_id,
      e.stay_id,
      e.anchor_age,
      e.intime,
      c.charttime,
      c.itemid,
      c.valuenum AS value
    FROM elderly_icu e
    JOIN `{ICU_DATASET}.chartevents` c
      ON e.stay_id = c.stay_id
    WHERE c.itemid IN ({itemid_list})
      AND c.valuenum IS NOT NULL
      AND c.charttime >= e.intime
      AND c.charttime < TIMESTAMP_ADD(e.intime, INTERVAL 24 HOUR)
    LIMIT {limit}
    """
    return client.query(query).to_dataframe()


def _fetch_item_metadata(client: bigquery.Client, itemids: list[int]) -> pd.DataFrame:
    if not itemids:
        return pd.DataFrame(columns=["itemid", "label", "abbreviation", "category", "unitname"])
    itemid_list = ", ".join(str(int(itemid)) for itemid in sorted(set(itemids)))
    query = f"""
    SELECT
      itemid,
      label,
      abbreviation,
      category,
      unitname
    FROM `{ICU_DATASET}.d_items`
    WHERE itemid IN ({itemid_list})
    """
    return client.query(query).to_dataframe()


def extract_vital_sign_sample(client: bigquery.Client) -> tuple[pd.DataFrame, pd.DataFrame]:
    sample_frames: list[pd.DataFrame] = []
    metadata_frames: list[pd.DataFrame] = []

    spo2_items = resolve_spo2_items(client)
    if not spo2_items.empty:
        spo2_itemids = spo2_items["itemid"].dropna().astype(int).tolist()
    else:
        spo2_itemids = []

    for spec in VITAL_SPECS:
        itemids = list(spec["itemids"])
        if spec["vital_sign"] == "SpO2":
            itemids = spo2_itemids
        if not itemids:
            LOGGER.warning("No itemids found for %s; skipping.", spec["vital_sign"])
            continue

        rows = _query_vital_rows(client, ICU_DATASET, itemids, limit=EVENT_LIMIT)
        if rows.empty:
            LOGGER.warning("No event rows found for %s; skipping.", spec["vital_sign"])
            continue

        metadata = _fetch_item_metadata(client, rows["itemid"].dropna().astype(int).tolist())
        metadata_frames.append(metadata.assign(vital_sign=spec["vital_sign"]))
        rows = rows.merge(metadata, on="itemid", how="left", suffixes=("", "_meta"))
        rows["vital_sign"] = spec["vital_sign"]
        rows["standard_low"] = spec["standard_low"]
        rows["standard_high"] = spec["standard_high"]
        rows["label"] = rows["label"].fillna(spec["vital_sign"])
        rows["unitname"] = rows["unitname"].fillna(spec["unitname_hint"])
        rows["age_group"] = rows["anchor_age"].apply(age_group_from_age)
        rows["hours_since_icu_admission"] = (
            pd.to_datetime(rows["charttime"], errors="coerce") - pd.to_datetime(rows["intime"], errors="coerce")
        ).dt.total_seconds() / 3600.0
        rows["time_window"] = rows["hours_since_icu_admission"].apply(lambda value: time_window_from_hours(value) if pd.notna(value) else None)
        rows = rows[[
            "subject_id",
            "hadm_id",
            "stay_id",
            "anchor_age",
            "age_group",
            "intime",
            "charttime",
            "hours_since_icu_admission",
            "time_window",
            "vital_sign",
            "itemid",
            "label",
            "unitname",
            "value",
            "standard_low",
            "standard_high",
        ]].copy()
        sample_frames.append(rows)

    if sample_frames:
        sample_df = pd.concat(sample_frames, ignore_index=True)
    else:
        sample_df = pd.DataFrame(
            columns=[
                "subject_id",
                "hadm_id",
                "stay_id",
                "anchor_age",
                "age_group",
                "intime",
                "charttime",
                "hours_since_icu_admission",
                "time_window",
                "vital_sign",
                "itemid",
                "label",
                "unitname",
                "value",
                "standard_low",
                "standard_high",
            ]
        )

    return sample_df, pd.concat(metadata_frames, ignore_index=True) if metadata_frames else pd.DataFrame()


def build_vital_signs_summary(sample_df: pd.DataFrame) -> pd.DataFrame:
    if sample_df.empty:
        return pd.DataFrame(
            columns=[
                "vital_sign",
                "itemid",
                "label",
                "unitname",
                "age_group",
                "time_window",
                "count",
                "mean",
                "median",
                "min",
                "max",
                "std",
                "p5",
                "p25",
                "p50",
                "p75",
                "p90",
                "percent_above_standard_high",
                "percent_below_standard_low",
                "standard_low",
                "standard_high",
                "is_demo_data",
            ]
        )

    summary_rows: list[dict[str, Any]] = []
    group_cols = ["vital_sign", "itemid", "label", "unitname", "age_group", "time_window", "standard_low", "standard_high"]
    for keys, group in sample_df.groupby(group_cols, dropna=False):
        values = pd.to_numeric(group["value"], errors="coerce").dropna()
        if values.empty:
            continue
        vital_sign, itemid, label, unitname, age_group, time_window, standard_low, standard_high = keys
        percent_above = None
        percent_below = None
        if pd.notna(standard_high):
            percent_above = float((values > float(standard_high)).mean() * 100.0)
        if pd.notna(standard_low):
            percent_below = float((values < float(standard_low)).mean() * 100.0)

        summary_rows.append(
            {
                "vital_sign": vital_sign,
                "itemid": int(itemid) if pd.notna(itemid) else None,
                "label": label,
                "unitname": unitname,
                "age_group": age_group,
                "time_window": time_window,
                "count": int(values.count()),
                "mean": float(values.mean()),
                "median": float(values.median()),
                "min": float(values.min()),
                "max": float(values.max()),
                "std": float(values.std(ddof=1)) if values.count() > 1 else 0.0,
                "p5": float(values.quantile(0.05)),
                "p25": float(values.quantile(0.25)),
                "p50": float(values.quantile(0.50)),
                "p75": float(values.quantile(0.75)),
                "p90": float(values.quantile(0.90)),
                "percent_above_standard_high": percent_above,
                "percent_below_standard_low": percent_below,
                "standard_low": float(standard_low) if pd.notna(standard_low) else None,
                "standard_high": float(standard_high) if pd.notna(standard_high) else None,
                "is_demo_data": False,
            }
        )

    summary_df = pd.DataFrame(summary_rows)
    if not summary_df.empty:
        summary_df = summary_df.sort_values(["vital_sign", "age_group", "time_window", "itemid"]).reset_index(drop=True)
    return summary_df


def _write_legacy_heart_rate_outputs(sample_df: pd.DataFrame, summary_df: pd.DataFrame) -> None:
    heart_rate_sample = sample_df[sample_df["vital_sign"] == "Heart Rate"].copy() if not sample_df.empty else pd.DataFrame()
    heart_rate_summary = summary_df[summary_df["vital_sign"] == "Heart Rate"].copy() if not summary_df.empty else pd.DataFrame()

    legacy_sample = heart_rate_sample[[
        "subject_id",
        "hadm_id",
        "stay_id",
        "anchor_age",
        "age_group",
        "intime",
        "charttime",
        "hours_since_icu_admission",
        "time_window",
        "vital_sign",
        "itemid",
        "label",
        "unitname",
        "value",
        "is_demo_data",
    ]].copy() if not heart_rate_sample.empty else pd.DataFrame()
    legacy_summary = heart_rate_summary[[
        "vital_sign",
        "itemid",
        "label",
        "unitname",
        "age_group",
        "time_window",
        "count",
        "mean",
        "median",
        "min",
        "max",
        "std",
        "p5",
        "p25",
        "p50",
        "p75",
        "p90",
        "percent_above_standard_high",
        "percent_below_standard_low",
        "standard_low",
        "standard_high",
        "is_demo_data",
    ]].copy() if not heart_rate_summary.empty else pd.DataFrame()

    if not legacy_sample.empty:
        _save_dataframe(legacy_sample, PROCESSED_DIR / "heart_rate_elderly_icu_sample.csv")
    if not legacy_summary.empty:
        _save_dataframe(legacy_summary, PROCESSED_DIR / "heart_rate_elderly_icu_summary.csv")


def run_pipeline() -> None:
    ensure_data_directories()
    client = build_client()

    try:
        LOGGER.info("Checking BigQuery connectivity for project %s", PROJECT_ID)
        check_bigquery_connection(client)
    except Exception as exc:  # noqa: BLE001
        LOGGER.error(
            "BigQuery connection failed. Check credentials, ADC login, and dataset access. Error: %s",
            exc,
        )
        if ALLOW_DEMO_FALLBACK:
            LOGGER.warning("ALLOW_DEMO_FALLBACK=True, writing demo outputs only.")
            demo_sample = _demo_sample_frame()
            demo_summary = _demo_summary_frame()
            _save_dataframe(demo_sample, PROCESSED_DIR / "vital_signs_elderly_icu_sample_demo.csv")
            _save_dataframe(demo_summary, PROCESSED_DIR / "vital_signs_elderly_icu_summary_demo.csv")
            _write_legacy_heart_rate_outputs(demo_sample, demo_summary)
        raise SystemExit(1) from exc

    elderly_icu = extract_elderly_icu_stays(client)
    vital_items = extract_icu_vital_items(client)
    sample_df, _ = extract_vital_sign_sample(client)

    if sample_df.empty:
        raise SystemExit("No vital sign rows were extracted from BigQuery.")

    summary_df = build_vital_signs_summary(sample_df)

    elderly_icu = elderly_icu.assign(is_demo_data=False)
    vital_items = vital_items.assign(is_demo_data=False)
    sample_df = sample_df.assign(is_demo_data=False)
    summary_df = summary_df.assign(is_demo_data=False)

    _save_dataframe(elderly_icu, PROCESSED_DIR / "elderly_icu_stays.csv")
    _save_dataframe(vital_items, PROCESSED_DIR / "icu_vital_items.csv")
    _save_dataframe(sample_df[[
        "subject_id",
        "hadm_id",
        "stay_id",
        "anchor_age",
        "age_group",
        "intime",
        "charttime",
        "hours_since_icu_admission",
        "time_window",
        "vital_sign",
        "itemid",
        "label",
        "unitname",
        "value",
        "is_demo_data",
    ]], PROCESSED_DIR / "vital_signs_elderly_icu_sample.csv")
    _save_dataframe(summary_df[[
        "vital_sign",
        "itemid",
        "label",
        "unitname",
        "age_group",
        "time_window",
        "count",
        "mean",
        "median",
        "min",
        "max",
        "std",
        "p5",
        "p25",
        "p50",
        "p75",
        "p90",
        "percent_above_standard_high",
        "percent_below_standard_low",
        "standard_low",
        "standard_high",
        "is_demo_data",
    ]], PROCESSED_DIR / "vital_signs_elderly_icu_summary.csv")
    _write_legacy_heart_rate_outputs(sample_df, summary_df)


def main() -> None:
    try:
        run_pipeline()
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001
        LOGGER.error("Phase 1 BigQuery extraction stopped: %s", exc)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
