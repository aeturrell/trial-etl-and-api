poetry config virtualenvs.in-project true

poetry export -f requirements.txt --output requirements.txt

uvicorn app.api:app --reload

year/2017/geo_code/E06000047
