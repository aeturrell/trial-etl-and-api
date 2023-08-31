# trial-etl-and-api

An attempt to stitch together some ETL with an API. Focusing on the automatic ETL part initially.

The project uses Google Cloud, Terraform, and Prefect.

## Python Environment

For convenience, conda is used to manage Python installations—but this isn't necessary for the Dockerfile. To install the dev environment locally, run

```bash
conda env create -f environment.yml
```

Then

```bash
conda activate etlapi
```

and then

```bash
poetry install
```

to install all of the packages in pyproject.toml. Then

```bash
poetry run pre-commit run --all-files
```

before each commit.

## ETL

The ETL scripts are:

- etl/extract.py — downloads deaths data by geography from [this ONS page](https://www.ons.gov.uk/peoplepopulationandcommunity/birthsdeathsandmarriages/deaths/datasets/monthlyfiguresondeathsregisteredbyareaofusualresidence), which has Excel files for each year. The script downloads them all.
- etl/transform.py - this takes downloaded files, opens them, finds the relevant sheets, cleans them, and stacks them in a tidy format in a parquet file. Challenges are:
  - Worksheet names change over time
  - File formats change (the file extension)
  - New data may be added in a new file, if the new data refer to January, or added into an existing file, if the month they refer to is not January
- etly/load.py — this step requires Google Cloud resources; it uploads the parquet file to a nominated Google bucket.

The *task* and *flow* decorators in these scripts are used by **Prefect** to create a Directed Acyclic Graph.

## Google Cloud Resources via Terraform

There is one element that operates on the cloud in this ETL formulation:

1. The Google storage bucket, which houses the most recent parquet file

Ensure you have the [Google CLI installed](https://cloud.google.com/sdk/docs/install-sdk) and authenticated. Once you have downloaded and installed it, run `gcloud init` to set it up. This is the point at which your computer becomes trusted to do things to your GCP account.

1. Create a new project on GCP.
2. In the same project, create a new Service Account under IAM. A service account can be used to manage access to Google Cloud services.
3. n the new service account, click on Actions then Manage keys. Create a new key which will be downloaded as a JSON file — keep it safe.

In that JSON file, there will be an email address for the service account in the format: projectname-service@projectid.iam.gserviceaccount.com. It is for **this account** that you will now need to go to the Google Cloud Console IAM and add the following roles:

- Storage admin

In principle, it looks like you can do this via Terraform too, as long as the Service Usage API is already enabled (see [this article on Stack Overflow](https://stackoverflow.com/questions/59055395/can-i-automatically-enable-apis-when-using-gcp-cloud-with-terraform), and this Terraform [page](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service)).

You will need to login, using (on your local computer)

```bash
gcloud auth login
```

If you have used Google CLI before, you may now need to run:

```bash
gcloud config set project $MY_PROJECT_ID
```

to log into this particular project.

### Terraform

To do *infrastructure as code*, we'll be using **Terraform**. To install terraform, the instructions vary depending on your operating system, but on Mac it can be done via `brew install terraform`.

There are four terraform files required:

- .terraform.version: contains the version
- main.tf: contains a recipe for the resources we wish to create
- variables.tf: declares the type and description of key resource variables
- terraform.tfvars: the actual names and IDs that you declared in variables.tf (NB: not in version control as sensitive)

Check the `.gitignore` for some useful Terraform specific lines.

To kick off terraforming, it's `terraform init`. If successful, you should see a message saying "Terraform has been successfully initialized!".

Next, run `terraform plan`, which will think through what you've asked for in `main.tf`.

Finally, to create the GCP resources, it's `terraform apply`.

## Deployment Plan via Prefect

Add the info needed for the blocks (bucket and GCP credentials) in the server UI using blocks -> add block. You can find more on [using blocks in Prefect here](https://docs.prefect.io/2.12.0/concepts/blocks/). The GCS Bucket block allows you to load data to GCP buckets; the GCP Credentials block handles authentication and is linked to by the former.

Prefect allows us to create a recipe that an orchestrator can use to send flows to agents. The below builds one of these recipes. It uses etl/main.py:main_flow for the flow. The `--cron` keyword argument is optional, and causes the orchestrator to start a flow (an execution of the DAG encapsulated by the given flow) every midnight.

```bash
prefect deployment build etl/main.py:main_flow --name main-flow --cron "0 0 * * *" -o main_flow-deployment.yaml --apply
```

This ensures that the recipe created in `main_flow-deployment.yaml` is also lined up in the orchestrator, and will be launched according to the schedule. (It's possible to launch flows based on [trigger events](https://www.prefect.io/blog/event-driven-flows-with-prefect) too.)

You can also apply existing deployments using:

```bash
prefect deployment apply main_flow-deployment.yaml
```

Note that none of this will actually run the flow, it just creates a recipe that an orchestrator will use to pass to an agent to run the flow. It will run if both orchestrator and agent are in place, and the scheduled moment is hit. Run

```bash
prefect deployment build etl/main.py:main_flow --name main-flow -o main_flow-deployment.yaml --apply
```

to create the deployment plan.

## Running

With prefect decorators in scripts and the flow function called in main, you can simply run scripts as you normally would, eg `poetry run python etl/transform.py`, to start a one-off Prefect agent task directly on the command line. However, this will be executed in the moment and not orchestrated. This is just one flow, not the flow you have deployed via the yaml file.

Prefect server is at http://127.0.0.1:4200/ and can be launched with:

```bash
poetry run prefect server start
```

Then

```bash
prefect agent start -q 'default'
```

To create an agent to take jobs. Note that you can use eg `--cron "0 0 * * *"` to schedule runs (in this case, the flows will run at midnight).

Note that even if a flow is not scheduled to run just yet, you can go to deployments in the UI and create an *ad hoc* one by clicking run.

## Running on the cloud

It's possible to have the flows run by Google Cloud Run, and the orchestrator work off a GCP Virtual Machine. You need to create a docker image for cloud run to do this. Ensuring this works well is not trivial though, especially if you are developing cross-platform.

## Context

Inspiration:

- [Github repo](https://github.com/RyanEricLamb/data-engineering-bus-tracker/tree/main/etl)
- [Blog post](https://medium.com/@ryanelamb/a-data-engineering-project-with-prefect-docker-terraform-google-cloudrun-bigquery-and-streamlit-3fc6e08b9398)
