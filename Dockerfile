FROM rocker/geospatial:4.3.3

# Installing missing dependencies
RUN install2.r -n 2 \
    AzureRMR \
    AzureStor

CMD ["bash"]