FROM docker.io/rocker/r-ver:4.4.1

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

#
# Bring in python project dependency information and set the virtual env
#

# Python from https://docs.astral.sh/uv/guides/integration/docker/
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Dependency information
COPY pyproject.toml ./pyproject.toml
COPY uv.lock ./uv.lock

# Set VIRTUAL_ENV variable at runtime
ENV VIRTUAL_ENV=/.venv

# Create the virtual environment
RUN uv venv "${VIRTUAL_ENV}"

# Update PATH to use the selected venv at runtime
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

# Dagster
COPY dagster_defs.py ./dagster_defs.py

CMD ["bash"]