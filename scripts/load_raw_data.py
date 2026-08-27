"""
Loads the two challenge source files into BigQuery as the landing zone.

Idempotent: creates the `landing` dataset if it does not exist, then replaces
the contents of raw_orders / raw_sales. Run it once, or any number of times —
the end state is identical.

The target project is not written into this file. It is read from $GCP_PROJECT,
and failing that from the gcloud default, so the repo runs against whatever
project the person cloning it can authenticate to.

This is not a dbt model. dbt's staging layer reads FROM raw_orders / raw_sales
via source(), and never writes here.

Usage (from anywhere):  python scripts/load_raw_data.py
"""
import os
from pathlib import Path

import pandas as pd
from google.cloud import bigquery

DATASET = "landing"
LOCATION = os.environ.get("BQ_LOCATION", "EU")

# Anchored to this file, not to the shell's working directory.
REPO_ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "raw_orders": {
        "path": REPO_ROOT / "data/raw/orders_recrutement.xlsx",
        "schema": [
            bigquery.SchemaField("date_date", "DATE"),
            bigquery.SchemaField("customers_id", "INT64"),
            bigquery.SchemaField("orders_id", "INT64"),
            bigquery.SchemaField("net_sales", "FLOAT64"),
        ],
    },
    "raw_sales": {
        "path": REPO_ROOT / "data/raw/sales_recrutement.xlsx",
        "schema": [
            bigquery.SchemaField("date_date", "DATE"),
            bigquery.SchemaField("customer_id", "INT64"),
            bigquery.SchemaField("order_id", "INT64"),
            bigquery.SchemaField("products_id", "INT64"),
            bigquery.SchemaField("net_sales", "FLOAT64"),
            bigquery.SchemaField("qty", "INT64"),
        ],
    },
}


def main() -> None:
    # project=None is meaningful, not a placeholder: it tells the client to
    # resolve the project from Application Default Credentials, which is what
    # `gcloud config set project` writes.
    client = bigquery.Client(project=os.environ.get("GCP_PROJECT"), location=LOCATION)

    project_id = client.project
    if not project_id:
        raise SystemExit(
            "No GCP project resolved. Set GCP_PROJECT, or run "
            "`gcloud config set project YOUR_PROJECT_ID`."
        )

    dataset = bigquery.Dataset(f"{project_id}.{DATASET}")
    dataset.location = LOCATION
    dataset = client.create_dataset(dataset, exists_ok=True)
    print(f"dataset ready: {dataset.full_dataset_id} ({dataset.location})")

    for table_name, cfg in FILES.items():
        df = pd.read_excel(cfg["path"])
        table_id = f"{project_id}.{DATASET}.{table_name}"

        job_config = bigquery.LoadJobConfig(
            schema=cfg["schema"],
            write_disposition="WRITE_TRUNCATE",  # rerunnable: replaces rather than appends
        )
        job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
        job.result()  # blocks, raises on failure

        table = client.get_table(table_id)
        print(f"{table_name}: loaded {table.num_rows} rows into {table_id}")


if __name__ == "__main__":
    main()