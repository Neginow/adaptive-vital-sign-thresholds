from google.cloud import bigquery

PROJECT_ID = "mimic-rag-2026-vinith"

client = bigquery.Client(project=PROJECT_ID)

query = """
SELECT
  subject_id,
  hadm_id,
  stay_id,
  intime,
  outtime,
  los
FROM `physionet-data.mimiciv_3_1_icu.icustays`
LIMIT 10
"""

df = client.query(query).to_dataframe()
print(df)