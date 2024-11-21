#' Exclusions Class
#'
#' Represents exclusion criteria for the pipeline.
#'
#' @slot path A string specifying the path to a CSV file containing exclusion
#' data. It should include at least the columns: `reference_date`,
#' `report_date`, ' `state_abb`, `disease`.
Exclusions <- S7::new_class(
  "Exclusions",
  properties = list(
    path = class_character
  )
)

#' GenerationInterval Class
#'
#' Represents the generation interval parameters.
#'
#' @slot path A string specifying the path to the generation interval CSV file.
#' @slot blob_storage_container Optional. The name of the blob storage container
#' to get it from. If NULL, will look locally.
GenerationInterval <- S7::new_class(
  "GenerationInterval",
  properties = list(
    path = class_character,
    blob_storage_container = class_character
  )
)

#' DelayInterval Class
#'
#' Represents the delay interval parameters.
#'
#' @slot path A string specifying the path to the delay interval CSV file.
#' @slot blob_storage_container Optional. The name of the blob storage container
#' to get it from. If NULL, will look locally.
DelayInterval <- S7::new_class(
  "DelayInterval",
  properties = list(
    path = class_character,
    blob_storage_container = class_character
  )
)

#' RightTruncation Class
#'
#' Represents the right truncation parameters.
#'
#' @slot path A string specifying the path to the right truncation CSV file.
#' @slot blob_storage_container Optional. The name of the blob storage container
#' to get it from. If NULL, will look locally.
RightTruncation <- S7::new_class(
  "RightTruncation",
  properties = list(
    path = class_character,
    blob_storage_container = class_character
  )
)

#' Parameters Class
#'
#' Holds all parameter-related configurations for the pipeline.
#'
#' @slot generation_interval An instance of `GenerationInterval` class.
#' @slot delay_interval An instance of `DelayInterval` class.
#' @slot right_truncation An instance of `RightTruncation` class.
Parameters <- S7::new_class(
  "Parameters",
  properties = list(
    generation_interval = class_GenerationInterval,
    delay_interval = class_DelayInterval,
    right_truncation = class_RightTruncation
  )
)

#' RtPrior Class
#'
#' Represents the Rt prior parameters.
#'
#' @slot mean A numeric value representing the mean of the Rt prior.
#' @slot sd A numeric value representing the standard deviation of the Rt prior.
RtPrior <- S7::new_class(
  "RtPrior",
  properties = list(
    mean = class_numeric,
    sd = class_numeric
  )
)

#' GpPrior Class
#'
#' Represents the Gaussian Process prior parameters.
#'
#' @slot alpha_sd A numeric value representing the standard deviation of the
#' alpha parameter in the GP prior.
GpPrior <- S7::new_class(
  "GpPrior",
  properties = list(
    alpha_sd = class_numeric
  )
)

#' Priors Class
#'
#' Holds all prior-related configurations for the pipeline.
#'
#' @slot rt An instance of `RtPrior` class.
#' @slot gp An instance of `GpPrior` class.
Priors <- S7::new_class(
  "Priors",
  properties = list(
    rt = class_RtPrior,
    gp = class_GpPrior
  )
)

#' Data Class
#'
#' Represents the data-related configurations.
#'
#' @slot path A string specifying the path to the data Parquet file.
#' @slot blob_storage_container Optional. The name of the blob storage container
#' to which the data file will be uploaded. If NULL, no upload will occur.
#' @slot report_date A list of strings representing report dates.
#' @slot reference_date A list of strings representing reference dates.
#' @slot production_date A list of strings representing production dates.
Data <- S7::new_class(
  "Data",
  properties = list(
    path = class_character,
    blob_storage_container = class_character,
    report_date = class_list,
    reference_date = class_list,
    production_date = class_list
  )
)

#' SamplerOpts Class
#'
#' Represents the sampler options for the pipeline.
#'
#' @slot cores An integer specifying the number of CPU cores to use.
#' @slot chains An integer specifying the number of Markov chains.
#' @slot iter_warmup An integer specifying the number of warmup iterations.
#' @slot iter_sampling An integer specifying the number of sampling iterations.
#' @slot adapt_delta A numeric value for the target acceptance probability.
#' @slot max_treedepth An integer specifying the maximum tree depth for the
#' sampler.
SamplerOpts <- S7::new_class(
  "SamplerOpts",
  properties = list(
    cores = class_integer,
    chains = class_integer,
    iter_warmup = class_integer,
    iter_sampling = class_integer,
    adapt_delta = class_numeric,
    max_treedepth = class_integer
  )
)

#' Config Class
#'
#' Represents the complete configuration for the pipeline.
#'
#' @slot job_id A string specifying the job.
#' @slot task_id A string specifying the task.
#' @slot min_reference_date A Date object representing the minimum reference
#' date.
#' @slot max_reference_date A Date object representing the maximum reference
#' date.
#' @slot disease A string specifying the disease being modeled.
#' @slot geo_value A string specifying the geographic value, usually a state.
#' @slot geo_type A string specifying the geographic type, usually "state".
#' @slot data An instance of `Data` class containing data configurations.
#' @slot seed An integer for setting the random seed.
#' @slot horizon An integer specifying the forecasting horizon.
#' @slot priors An instance of `Priors` class containing prior configurations.
#' @slot parameters An instance of `Parameters` class containing parameter
#' configurations.
#' @slot sampler_opts An instance of `SamplerOpts` class containing sampler
#' options.
#' @slot exclusions An instance of `Exclusions` class containing exclusion
#' criteria.
#' @slot config_version A numeric value specifying the configuration version.
#' @slot quantile_width A list of numeric values representing the desired
#' quantiles.
#' @slot model A string specifying the model to be used.
#' @slot report_date A Date object representing the report date.
Config <- S7::new_class(
  "Config",
  properties = list(
    job_id = class_character,
    task_id = class_character,
    min_reference_date = class_Date,
    max_reference_date = class_Date,
    disease = class_character,
    geo_value = class_character,
    geo_type = class_character,
    data = class_Data,
    seed = class_integer,
    horizon = class_integer,
    priors = class_Priors,
    parameters = class_Parameters,
    sampler_opts = class_SamplerOpts,
    exclusions = class_Exclusions,
    config_version = class_numeric,
    quantile_width = class_list,
    model = class_character,
    report_date = class_Date
  )
)
