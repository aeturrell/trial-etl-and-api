# trial-etl-and-api

An attempt to stitch together some ETL with an API. Focusing on the automatic ETL part initially.

Prefect server is at http://127.0.0.1:4200/ and can be launched with:

```bash
poetry run prefect server start
```

With prefect decorators in scripts and the flow function called in main, you can simply run scripts as you normally would, eg `poetry run python etl/transform.py`, to start the Prefect server task.

Inspiration:

- [Github repo](https://github.com/RyanEricLamb/data-engineering-bus-tracker/tree/main/etl)
- [Blog post](https://medium.com/@ryanelamb/a-data-engineering-project-with-prefect-docker-terraform-google-cloudrun-bigquery-and-streamlit-3fc6e08b9398)
