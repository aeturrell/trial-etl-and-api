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

- etl/extract.py — downloads deaths data by geography from [this ONS page](), which has Excel files for each year. The script downloads them all.
- etl/transform.py - this takes downloaded files, opens them, finds the relevant sheets, cleans them, and stacks them in a tidy format in a parquet file. Challenges are:
  - Worksheet names change over time
  - File formats change (the file extension)
  - New data may be added in a new file, if the new data refer to January, or added into an existing file, if the month they refer to is not January
- etly/load.py — this step requires Google Cloud resources; it uploads the parquet file to a nominated Google bucket.

The *task* and *flow* decorators in these scripts are used by **Prefect** to create a

## Google Cloud Resources via Terraform

There are up to three elements that operate on the cloud:

1. The Google storage bucket, which houses the most recent parquet file
2. Google Cloud Run, to (optionally) provide a runner agent (a computer that carries out the ETL) in the cloud
3. (Optionally) a Google VM, to host the orchestration, ie to direct agents, in the cloud

Ensure you have the [Google CLI installed](https://cloud.google.com/sdk/docs/install-sdk) and authenticated. Once you have downloaded and installed it, run `gcloud init` to set it up. This is the point at which your computer becomes trusted to do things to your GCP account.

1. Create a new project on GCP.
2. In the same project, create a new Service Account under IAM. A service account can be used to manage access to Google Cloud services.
3. n the new service account, click on Actions then Manage keys. Create a new key which will be downloaded as a JSON file — keep it safe.

In that JSON file, there will be an email address for the service account in the format: projectname-service@projectid.iam.gserviceaccount.com. It is for **this account** that you will now need to go to the Google Cloud Console IAM and add the following roles:

- Cloud run admin
- Storage admin
- Artifact registry admin
- Artifact registry repository admin
- Artifact Registry Writer

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

Prefect allows us to create a recipe that an orchestrator can use to send flows to agents. The below builds one of these recipes. It uses etl/main.py:main_flow for the flow. The `--cron` keyword argument is optional, and causes the orchestrator to start a flow (an execution of the DAG encapsulated by the given flow) every midnight.

```bash
prefect deployment build etl/main.py:main_flow --name main-flow --cron "0 0 * * *"
```

To ensure that the recipe created in `main_flow-deployment.yaml` is lined up in the orchestrator, and will be launched according to the schedule. (It's possible to launch flows based on [trigger events](https://www.prefect.io/blog/event-driven-flows-with-prefect) too.)

```bash
prefect deployment apply main_flow-deployment.yaml
```

to create a deployment 'main-flow/main-flow', which can be seen on the (local) server provided by `poetry run prefect server start`.

Note that none of this will actually run the flow, it just creates a recipe that an orchestrator will use to pass to an agent to run the flow. It will run if both orchestrator and agent are in place, and the scheduled moment is hit.

## Docker container

This will be useful only for Cloud Run. Note that the Docker container only grabs the Python environment via a pre-built Python container and packages, which comes via Poetry. **Do not copy the entire repo over in your Dockerfile** as it will likely contain secrets.

```bash
docker build --pull --rm -f "Dockerfile" -t trialetlandapi:latest "."
```

to build the Dockerfile. Use `docker tag SOURCE_IMAGE[:TAG] TARGET_IMAGE[:TAG]` to tag the image ready for the registry. eg

```bash
docker tag trialetlandapi:latest europe-west2-docker.pkg.dev/PROJECT-ID/registry_id/trialetlandapi:latest
```

where registry_id is the same as the one in terraform.tfvars. europe-west2-docker.pkg.dev is the host name. Configure gcloud to work with docker:

```bash
gcloud auth configure-docker europe-west2-docker.pkg.dev
```

Push the image with

```bash
docker push HOST-NAME/PROJECT-ID/REPOSITORY/IMAGE
```

You’ll then see your Docker image available in Artifact Registry.

## Running

### General

With prefect decorators in scripts and the flow function called in main, you can simply run scripts as you normally would, eg `poetry run python etl/transform.py`, to start a one-off Prefect agent task directly on the command line. However, this will be executed in the moment and not orchestrated.

### Running everything locally

This means running the server / orchestrator locally, and running the worker pool locally too.

Prefect server is at http://127.0.0.1:4200/ and can be launched with:

```bash
poetry run prefect server start
```

Add the info needed for the blocks (bucket, GCP credentials, cloud run job—not used) in the server UI. For this local running only the first two blocks are needed. Run

```bash
prefect deployment build etl/main.py:main_flow --name main-flow -o main_flow-deployment.yaml --apply
```

to create the deployment plan.

Then

```bash
prefect agent start -q 'default'
```

To create an agent to take jobs.

### Running the agent in the cloud

In this case, Google Cloud Run takes the job. Ensure there's a Cloud Run block that links to the GCP block. Then

To create a deployment file and to launch the cloud run:

```bash
prefect deployment build etl/main.py:main_flow --name main-flow --cron "0 0 * * *" -ib cloud-run-job/etlapi-cloud-run -o main_flow-deployment.yaml --apply
```

where etlapi-cloud-run is the name of a prefect cloud run block. NB the cron setting, which makes the deployment happen at midnight each day.

### Running the agent and the orchestrator in the cloud

This is like the previous case, except that we will orchestrate in the cloud too. For this, we need another block.

## Context

Inspiration:

- [Github repo](https://github.com/RyanEricLamb/data-engineering-bus-tracker/tree/main/etl)
- [Blog post](https://medium.com/@ryanelamb/a-data-engineering-project-with-prefect-docker-terraform-google-cloudrun-bigquery-and-streamlit-3fc6e08b9398)
