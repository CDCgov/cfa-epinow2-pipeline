FROM docker.io/rocker/r-ver:4.4.1

# We need curl to get UV and git to get a python dependency from GitHub
RUN apt-get update && apt-get install -y curl git

# install uv and add to PATH
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

ARG WORKDIR=/app
WORKDIR ${WORKDIR}

# Python from https://docs.astral.sh/uv/guides/integration/docker/
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/ 

# Some handy uv environment variables
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV UV_PYTHON_CACHE_DIR=/root/.cache/uv/python

#
# Bring in python project dependency information and set the virtual env
#

# Dependency information
COPY pyproject.toml ./pyproject.toml
COPY uv.lock ./uv.lock

# Set VIRTUAL_ENV variable at runtime
ENV VIRTUAL_ENV=/cfa-stf-routine-forecasting/.venv

# Create the virtual environment
RUN uv venv "${VIRTUAL_ENV}"

# Update PATH to use the selected venv at runtime
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

# Sync all python dependencies (excluding the local project itself)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --no-install-project --no-dev


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

# install the dagster workflow dependencies
RUN uv sync --script dagster_defs.py --active

CMD ["bash"]
