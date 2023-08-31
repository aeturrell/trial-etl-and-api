# Set base image (this loads the Debian Linux operating system)
FROM python:3.10.4-buster

# Update Linux package list and install some key libraries for compiling code
RUN apt-get update && apt-get install -y gcc libffi-dev g++ libssl-dev openssl build-essential graphviz

# Install Latex
RUN apt-get --no-install-recommends install -y texlive-latex-extra

# Ensure python points to this version of Python
RUN update-alternatives --install /usr/bin/python python /usr/local/bin/python3.10 4
RUN update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.10 4

# ensure local python is preferred over any built-in python
ENV PATH /usr/local/bin:$PATH

ARG YOUR_ENV

ENV YOUR_ENV=${YOUR_ENV} \
  PYTHONFAULTHANDLER=1 \
  PYTHONUNBUFFERED=1 \
  PYTHONHASHSEED=random \
  PIP_NO_CACHE_DIR=off \
  PIP_DISABLE_PIP_VERSION_CHECK=on \
  PIP_DEFAULT_TIMEOUT=100 \
  POETRY_VERSION=1.5.1

# System deps:
RUN pip install "poetry==$POETRY_VERSION"

RUN python -m pip install nox-poetry

# set the working directory in the container
WORKDIR /app

RUN poetry cache clear pypi --all

# Copy only packages to docker layer
COPY pyproject.toml /app/

RUN poetry lock

# Install the packages
RUN poetry install

# Signal that the dockerfile is built
RUN echo "Success building the etlapi container!"
