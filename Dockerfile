FROM rocker/geospatial:4.4.1

# Installing missing dependencies
RUN install2.r -n 2 \
    AzureStor \
    AzureRMR \
    EpiNow2

# Will copy the package to the container preserving the directory structure
COPY . pkg/

# Install the full package while leaving the tar.gz file in the
# container for later use.
RUN R CMD build --no-build-vignettes pkg && \
    R CMD INSTALL CFAEpiNow2Pipeline_*.tar.gz

RUN R CMD check CFAEpiNow2Pipeline_*.tar.gz

CMD ["bash"]