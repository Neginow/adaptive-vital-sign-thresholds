# ICU Trajectory RAG Assistant - Phase 1

## 1. Project overview

This repository contains a local Python RAG layer added alongside the historical R project. Phase 1 remains a retrieval-and-generation prototype for ICU vital signs, with MIMIC-IV statistics and project documents as sources.

## 2. Phase 1 objective

The goal of Phase 1 is still simple: user question -> local retrieval over indexed chunks -> sourced answer. The system is intended for academic interpretation and literature-style exploration, not for clinical decision support.

## 3. What this phase does

The pipeline now extracts small BigQuery samples for multiple routine ICU vital signs, prepares RAG-ready documents from CSV and markdown/text sources, chunks the content, builds a local TF-IDF index, retrieves the most relevant chunks, and produces a structured template-based answer with sources.

The first version started with Heart Rate only to validate the pipeline end to end. The current version extends the same Phase 1 design to Respiratory Rate, Blood Pressure, MAP, Temperature, and SpO2 when a true measurement item is found.

## 4. What this phase does NOT do

This Phase 1 prototype does not implement:
- MCP;
- agents;
- function calling;
- tool calling;
- multi-agent orchestration;
- clinical diagnosis;
- production deployment.

## 5. Data sources

Primary sources:
- `physionet-data.mimiciv_3_1_icu`
- `physionet-data.mimiciv_3_1_hosp`

Local sources:
- `README.md`
- markdown/text files in the project
- files added later under `data/rag_documents/`
- generated CSV summaries under `data/processed/`

## 6. BigQuery configuration

The project ID is `mimic-rag-2026-vinith`. Authentication is expected to be configured locally with Application Default Credentials.

Useful commands:

```bash
gcloud config set project mimic-rag-2026-vinith
gcloud auth application-default login
gcloud auth application-default set-quota-project mimic-rag-2026-vinith
bq ls physionet-data:mimiciv_3_1_icu
```

## 7. MIMIC-IV tables used

Phase 1 currently focuses on:
- `patients`
- `icustays`
- `chartevents`
- `d_items`

The extraction is intentionally conservative: it starts with `LIMIT`, filters `chartevents` by itemid before any time-window analysis, and excludes alarm items, care-plan items, MD note items, APACHE score items, sensor placement items, and alarm-limit items from the vital-sign summary layer.

## 8. RAG pipeline

1. Extract a small elderly ICU cohort from BigQuery.
2. Extract vital-sign metadata from `d_items`.
3. Extract limited vital-sign samples from `chartevents`.
4. Compute age-group and time-window summaries in Python.
5. Convert statistics and project documents into RAG documents.
6. Chunk the documents.
7. Build a local TF-IDF index.
8. Retrieve chunks and generate a structured sourced answer.

Retrieval now infers age group, time window, and vital sign from the question and boosts matching chunks accordingly.
It also detects the query intent so patient-value, threshold, concept, dataset, and pipeline questions follow different retrieval and answer paths.
If a requested vital sign has no matching statistical summary in the current index, the system returns a clear missing-vital response instead of borrowing an unrelated percentile summary.

## 9. How to run

Create and activate the Python environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Run the pipeline:

```bash
python -m src.bigquery_extract_mimic
python -m src.prepare_rag_documents
python -m src.chunk_documents
python -m src.build_rag_index
```

Run the local app:

```bash
streamlit run app.py
```

## 10. Example questions

- For a patient aged 82 with mean HR 104 bpm in the first 24h ICU stay, is this value high?
- For a patient aged 78 with MAP 62 mmHg in the first 24h ICU stay, is this low?
- For a patient aged 86 with respiratory rate 24 in the first 12h ICU stay, is this elevated?
- How should SpO2 below 92% be interpreted in elderly ICU patients?
- What is the difference between standard thresholds and MIMIC-IV percentile-based summaries?
- Why are alarm items excluded from the vital sign pipeline?

## 11. Limitations

The current prototype is local, lightweight, and text-driven. It does not model causal inference, it does not represent full clinical context, and it should not be used for direct clinical decisions. If BigQuery access fails, the pipeline stops cleanly unless an explicit demo fallback is enabled in code.

## 12. Next step: Phase 2 Agent with tools

Phase 2 will be a separate step and may add tool-using agents for richer analysis. That phase is intentionally out of scope here.
