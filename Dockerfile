FROM docker.io/rocker/r-ver:4.4.1

# We need curl to get UV and git to get a python dependency from GitHub
RUN apt-get update && apt-get install -y curl git

# install uv and add to PATH
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# WORKDIR MUST be /opt/dagster/code_location/<your repo name>
ARG WORKDIR=/opt/dagster/code_location/cfa-epinow2-pipeline
WORKDIR ${WORKDIR}

# Will copy the package to the container preserving the directory structure
RUN mkdir -p pkg

COPY ./DESCRIPTION pkg/

# Installing missing dependencies (removing pandoc-citeproc install)
RUN apt-get update
RUN install2.r pak
# dependencies = TRUE means we install `suggests` too
RUN Rscript -e 'pak::local_install_deps("pkg", upgrade = FALSE, dependencies = TRUE)'
# The cmdstan version will need to be incrementally updated
# Must also manually bump cmdstan version `.github/workflows` when updating
RUN Rscript -e 'cmdstanr::install_cmdstan(version="2.36.0")'
# This requires access to the Azure Container Registry

# Will copy the package to the container preserving the directory structure
COPY . pkg/

# Install the full package while leaving the tar.gz file in the
# container for later use.
RUN R CMD build --no-build-vignettes --no-manual pkg && \
    R CMD INSTALL CFAEpiNow2Pipeline_*.tar.gz

# Ensure the package is working properly
RUN R CMD check --no-build-vignettes --no-manual CFAEpiNow2Pipeline_*.tar.gz

# add Dagster workflow file
COPY ./dagster_defs.py .

# the virtual environment MUST be .venv in the same directory as your dagster workflow file
ENV VIRTUAL_ENV=${WORKDIR}/.venv
# create a virtual environment for the dagster workflows
RUN uv venv ${VIRTUAL_ENV}

# install the dagster workflow dependencies
RUN uv sync --script dagster_defs.py --active

# add the dagster workflow dependencies to the system path
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

CMD ["bash"]
