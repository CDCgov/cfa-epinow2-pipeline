#' Exclusions Class
#'
#' Represents exclusion criteria for the pipeline.
#'
#' @param path A string specifying the path to a CSV file containing exclusion
#' data. It should include at least the columns: `reference_date`,
#' `report_date`, ' `state_abb`, `disease`.
#' @export
Exclusions <- S7::new_class(
  "Exclusions",
  properties = list(
    path = S7::class_character
  )
)

#' GenerationInterval Class
#'
#' Represents the generation interval parameters.
#'
#' @param path A string specifying the path to the generation interval CSV file.
#' @param blob_storage_container Optional. The name of the blob storage
#' container to get it from. If NULL, will look locally.
#' @export
GenerationInterval <- S7::new_class(
  "GenerationInterval",
  properties = list(
    path = S7::class_character,
    blob_storage_container = S7::class_character
  )
)

#' DelayInterval Class
#'
#' Represents the delay interval parameters.
#'
#' @param path A string specifying the path to the delay interval CSV file.
#' @param blob_storage_container Optional. The name of the blob storage
#' container to get it from. If NULL, will look locally.
#' @export
DelayInterval <- S7::new_class(
  "DelayInterval",
  properties = list(
    path = S7::class_character,
    blob_storage_container = S7::class_character
  )
)

#' RightTruncation Class
#'
#' Represents the right truncation parameters.
#'
#' @param path A string specifying the path to the right truncation CSV file.
#' @param blob_storage_container Optional. The name of the blob storage
#' container to get it from. If NULL, will look locally.
#' @export
RightTruncation <- S7::new_class(
  "RightTruncation",
  properties = list(
    path = S7::class_character,
    blob_storage_container = S7::class_character
  )
)

#' Parameters Class
#'
#' Holds all parameter-related configurations for the pipeline.
#'
#' @param generation_interval An instance of `GenerationInterval` class.
#' @param delay_interval An instance of `DelayInterval` class.
#' @param right_truncation An instance of `RightTruncation` class.
#' @export
Parameters <- S7::new_class(
  "Parameters",
  properties = list(
    generation_interval = S7::S7_class(GenerationInterval()),
    delay_interval = S7::S7_class(DelayInterval()),
    right_truncation = S7::S7_class(RightTruncation())
  )
)

#' RtPrior Class
#'
#' Represents the Rt prior parameters.
#'
#' @param mean A numeric value representing the mean of the Rt prior.
#' @param sd A numeric value representing the standard deviation of the Rt
#' prior.
#' @export
RtPrior <- S7::new_class(
  "RtPrior",
  properties = list(
    mean = S7::class_numeric,
    sd = S7::class_numeric
  )
)

#' GpPrior Class
#'
#' Represents the Gaussian Process prior parameters.
#'
#' @param alpha_sd A numeric value representing the standard deviation of the
#' alpha parameter in the GP prior.
#' @export
GpPrior <- S7::new_class(
  "GpPrior",
  properties = list(
    alpha_sd = S7::class_numeric
  )
)

#' Priors Class
#'
#' Holds all prior-related configurations for the pipeline.
#'
#' @param rt An instance of `RtPrior` class.
#' @param gp An instance of `GpPrior` class.
#' @export
Priors <- S7::new_class(
  "Priors",
  properties = list(
    rt = S7::S7_class(RtPrior()),
    gp = S7::S7_class(GpPrior())
  )
)

#' Data Class
#'
#' Represents the data-related configurations.
#'
#' @param path A string specifying the path to the data Parquet file.
#' @param blob_storage_container Optional. The name of the blob storage
#' container to which the data file will be uploaded. If NULL, no upload will
#' occur.
#' @param report_date A list of strings representing report dates.
#' @param reference_date A list of strings representing reference dates.
#' @param production_date A list of strings representing production dates.
#' @export
Data <- S7::new_class(
  "Data",
  properties = list(
    path = S7::class_character,
    blob_storage_container = S7::class_character,
    report_date = S7::class_list,
    reference_date = S7::class_list,
    production_date = S7::class_list
  )
)

#' SamplerOpts Class
#'
#' Represents the sampler options for the pipeline.
#'
#' @param cores An integer specifying the number of CPU cores to use.
#' @param chains An integer specifying the number of Markov chains.
#' @param iter_warmup An integer specifying the number of warmup iterations.
#' @param iter_sampling An integer specifying the number of sampling iterations.
#' @param adapt_delta A numeric value for the target acceptance probability.
#' @param max_treedepth An integer specifying the maximum tree depth for the
#' sampler.
#' @export
SamplerOpts <- S7::new_class(
  "SamplerOpts",
  properties = list(
    cores = S7::class_integer,
    chains = S7::class_integer,
    iter_warmup = S7::class_integer,
    iter_sampling = S7::class_integer,
    adapt_delta = S7::class_numeric,
    max_treedepth = S7::class_integer
  )
)

#' Config Class
#'
#' Represents the complete configuration for the pipeline.
#'
#' @param job_id A string specifying the job.
#' @param task_id A string specifying the task.
#' @param min_reference_date A Date object representing the minimum reference
#' date.
#' @param max_reference_date A Date object representing the maximum reference
#' date.
#' @param disease A string specifying the disease being modeled.
#' @param geo_value A string specifying the geographic value, usually a state.
#' @param geo_type A string specifying the geographic type, usually "state".
#' @param data An instance of `Data` class containing data configurations.
#' @param seed An integer for setting the random seed.
#' @param horizon An integer specifying the forecasting horizon.
#' @param priors An instance of `Priors` class containing prior configurations.
#' @param parameters An instance of `Parameters` class containing parameter
#' configurations.
#' @param sampler_opts An instance of `SamplerOpts` class containing sampler
#' options.
#' @param exclusions An instance of `Exclusions` class containing exclusion
#' criteria.
#' @param config_version A numeric value specifying the configuration version.
#' @param quantile_width A vector of numeric values representing the desired
#' quantiles.
#' @param model A string specifying the model to be used.
#' @param report_date A Date object representing the report date.
#' @export
Config <- S7::new_class(
  "Config",
  properties = list(
    job_id = S7::class_character,
    task_id = S7::class_character,
    min_reference_date = S7::class_Date,
    max_reference_date = S7::class_Date,
    report_date = S7::class_Date,
    disease = S7::class_character,
    geo_value = S7::class_character,
    geo_type = S7::class_character,
    data = S7::S7_class(Data()),
    seed = S7::class_integer,
    horizon = S7::class_integer,
    priors = S7::S7_class(Priors()),
    parameters = S7::S7_class(Parameters()),
    sampler_opts = S7::S7_class(SamplerOpts()),
    exclusions = S7::S7_class(Exclusions()),
    config_version = S7::new_property(S7::class_numeric, default = 1),
    quantile_width = S7::new_property(S7::class_vector, default = c(0.5, 0.95)),
    model = S7::new_property(S7::class_character, default = "EpiNow2")
  )
)
