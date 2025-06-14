% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/config.R
\name{Parameters}
\alias{Parameters}
\title{Parameters Class}
\usage{
Parameters(
  as_of_date = class_missing,
  generation_interval = class_missing,
  delay_interval = class_missing,
  right_truncation = class_missing
)
}
\arguments{
\item{as_of_date}{A string representing the as-of date. Formatted as
"YYYY-MM-DD".}

\item{generation_interval}{An instance of \code{GenerationInterval} class.}

\item{delay_interval}{An instance of \code{DelayInterval} class.}

\item{right_truncation}{An instance of \code{RightTruncation} class.}
}
\description{
Holds all parameter-related configurations for the pipeline.
}
\seealso{
Other config: 
\code{\link{Config}()},
\code{\link{Data}()},
\code{\link{Interval}},
\code{\link{read_json_into_config}()}
}
\concept{config}
