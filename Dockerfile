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

RUN git config --global --add safe.directory "$GITHUB_WORKSPACE" && \
    Rscript -e "roxygen2::roxygenize('pkg')" && \
    git diff --exit-code man || (echo "::error::Documentation is not up to date. Run 'roxygen2::roxygenize()' locally to re-render." && exit 1)

CMD ["bash"]
