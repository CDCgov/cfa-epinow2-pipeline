% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/config.R
\name{Interval}
\alias{Interval}
\title{Interval Class}
\usage{
Interval(path = class_missing, blob_storage_container = class_missing)
}
\arguments{
\item{path}{A string specifying the path to the generation interval CSV file.}

\item{blob_storage_container}{Optional. The name of the blob storage
container to get it from. If NULL, will look locally.}
}
\description{
Represents a generic interval. Meant to be subclassed.
}
\seealso{
Other config: 
\code{\link{Config}()},
\code{\link{Data}()},
\code{\link{Parameters}()},
\code{\link{read_json_into_config}()}
}
\concept{config}
