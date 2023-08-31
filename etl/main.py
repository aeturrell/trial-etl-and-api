from extract import get_ons_deaths_data
from transform import transform_from_excel_to_tidy_parquet
from load import main_load_deaths_gcs
from prefect import flow


@flow
def main_flow():

    get_ons_deaths_data()
    transform_from_excel_to_tidy_parquet(wait_for=[get_ons_deaths_data])
    main_load_deaths_gcs(wait_for=[transform_from_excel_to_tidy_parquet])


if __name__ == "__main__":
    main_flow()
