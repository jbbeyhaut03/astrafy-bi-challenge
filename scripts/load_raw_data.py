"""
Loads the two challenge source files into BigQuery as the landing zone.
Run once, or whenever the source files change. This is not a dbt model —
dbt's staging layer reads FROM raw_orders / raw_sales, it never writes here.
"""
from pathlib import Path
import pandas as pd
from google.cloud import bigquery

PROJECT_ID = "astrafy-bi-challenge"
DATASET = "landing"

client = bigquery.Client(project=PROJECT_ID)

FILES = {
    "raw_orders": {
        "path": Path("data/raw/orders_recrutement.xlsx"),
        "schema": [
            bigquery.SchemaField("date_date", "DATE"),
            bigquery.SchemaField("customers_id", "INT64"),
            bigquery.SchemaField("orders_id", "INT64"),
            bigquery.SchemaField("net_sales", "FLOAT64"),
        ],
    },
    "raw_sales": {
        "path": Path("data/raw/sales_recrutement.xlsx"),
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

for table_name, cfg in FILES.items():
    df = pd.read_excel(cfg["path"])
    table_id = f"{PROJECT_ID}.{DATASET}.{table_name}"

    job_config = bigquery.LoadJobConfig(
        schema=cfg["schema"],
        write_disposition="WRITE_TRUNCATE",  # rerunnable: replaces rather than appends
    )
    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()  # blocks, raises on failure

    table = client.get_table(table_id)
    print(f"{table_name}: loaded {table.num_rows} rows into {table_id}")