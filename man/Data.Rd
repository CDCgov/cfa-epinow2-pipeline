% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/config.R
\name{Data}
\alias{Data}
\title{Data Class}
\usage{
Data(
  path = character(0),
  blob_storage_container = character(0),
  report_date = character(0),
  reference_date = character(0)
)
}
\arguments{
\item{path}{A string specifying the path to the data Parquet file.}

\item{blob_storage_container}{Optional. The name of the blob storage
container to which the data file will be uploaded. If NULL, no upload will
occur.}

\item{report_date}{A list of strings representing report dates.}

\item{reference_date}{A list of strings representing reference dates.}
}
\description{
Represents the data-related configurations.
}
\seealso{
Other config: 
\code{\link{Config}()},
\code{\link{Exclusions}()},
\code{\link{Interval}},
\code{\link{Parameters}()},
\code{\link{read_json_into_config}()}
}
\concept{config}
