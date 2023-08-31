import os
from pathlib import Path

import pandas as pd
import toml
from prefect import flow
from prefect import task
from prefect_gcp.cloud_storage import GcsBucket

# Read local `config.toml` file.
config = toml.load("config.toml")


@task()
def load_deaths_to_gcs(pref_gcs_block_name: str, from_path: str) -> None:
    """Load the deaths data to Google Bucket"""

    gcs_block = GcsBucket.load(pref_gcs_block_name)
    gcs_block.upload_from_path(from_path=from_path, to_path="etlapi-data")
    os.remove(from_path)
    return None


@flow()
def main_load_deaths_gcs():
    pref_gcs_block_name = "etlapi-bucket"
    from_path = Path(config["downloads_location"]) / "deaths_data.parquet"
    load_deaths_to_gcs(pref_gcs_block_name=pref_gcs_block_name, from_path=from_path)


if __name__ == "__main__":
    main_load_deaths_gcs()
