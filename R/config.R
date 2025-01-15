character_or_null <- S7::new_union(S7::class_character, NULL)

#' Exclusions Class
#'
#' Represents exclusion criteria for the pipeline.
#'
#' @param path A string specifying the path to a CSV file containing exclusion
#' data. It should include at least the columns: `reference_date`,
#' `report_date`, `state_abb`, `disease`.
#' @param blob_storage_container Optional. The name of the blob storage
#' container to get it from. If NULL, will look locally.
#' @family config
#' @export
Exclusions <- S7::new_class( # nolint: object_name_linter
  "Exclusions",
  properties = list(
    path = character_or_null,
    blob_storage_container = character_or_null
  )
)

#' Interval Class
#'
#' Represents a generic interval. Meant to be subclassed.
#'
#' @param path A string specifying the path to the generation interval CSV file.
#' @param blob_storage_container Optional. The name of the blob storage
#' container to get it from. If NULL, will look locally.
#' @name Interval
#' @family config
Interval <- S7::new_class( # nolint: object_name_linter
  "Interval",
  properties = list(
    path = character_or_null,
    blob_storage_container = character_or_null
  )
)

#' GenerationInterval Class
#'
#' Represents the generation interval parameters.
#' @rdname Interval
#' @family config
#' @export
GenerationInterval <- S7::new_class( # nolint: object_name_linter
  "GenerationInterval",
  parent = Interval,
)

#' DelayInterval Class
#'
#' Represents the delay interval parameters.
#' @rdname Interval
#' @family config
#' @export
DelayInterval <- S7::new_class( # nolint: object_name_linter
  "DelayInterval",
  parent = Interval,
)

#' RightTruncation Class
#'
#' Represents the right truncation parameters.
#' @rdname Interval
#' @family config
#' @export
RightTruncation <- S7::new_class( # nolint: object_name_linter
  "RightTruncation",
  parent = Interval,
)

#' Parameters Class
#'
#' Holds all parameter-related configurations for the pipeline.
#' @param as_of_date A string representing the as-of date. Formatted as
#' "YYYY-MM-DD".
#' @param generation_interval An instance of `GenerationInterval` class.
#' @param delay_interval An instance of `DelayInterval` class.
#' @param right_truncation An instance of `RightTruncation` class.
#' @family config
#' @export
Parameters <- S7::new_class( # nolint: object_name_linter
  "Parameters",
  properties = list(
    as_of_date = S7::class_character,
    generation_interval = S7::S7_class(GenerationInterval()),
    delay_interval = S7::S7_class(DelayInterval()),
    right_truncation = S7::S7_class(RightTruncation())
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
#' @family config
#' @export
Data <- S7::new_class( # nolint: object_name_linter
  "Data",
  properties = list(
    path = S7::class_character,
    blob_storage_container = character_or_null,
    report_date = S7::class_character,
    reference_date = S7::class_character
  )
)

#' Config Class
#'
#' Represents the complete configuration for the pipeline.
#'
#' @param job_id A string specifying the job.
#' @param task_id A string specifying the task.
#' @param min_reference_date A string representing the minimum reference
#' date. Formatted as "YYYY-MM-DD".
#' @param max_reference_date A string representing the maximum reference
#' date. Formatted as "YYYY-MM-DD".
#' @param production_date A string representing the production date.
#' Formatted as "YYYY-MM-DD".
#' @param disease A string specifying the disease being modeled. One of
#'    `"COVID-19"` or `"Influenza"`.
#' @param geo_value An uppercase, two-character string specifying the geographic
#'   value, usually a state or `"US"` for national data.
#' @param geo_type A string specifying the geographic type, usually "state".
#' @param data An instance of `Data` class containing data configurations.
#' @param seed An integer for setting the random seed.
#' @param horizon An integer specifying the forecasting horizon.
#' @param priors A list of lists. The first level should contain the key `rt`
#' with elements `mean` and `sd` and the key `gp` with element `alpha_sd`.
#' @param parameters An instance of `Parameters` class containing parameter
#' configurations.
#' @param sampler_opts A list. The Stan sampler options to be passed through
#' EpiNow2. It has required keys: `cores`, `chains`, `iter_warmup`,
#' `iter_sampling`, `max_treedepth`, and `adapt_delta`.
#' @param exclusions An instance of `Exclusions` class containing exclusion
#' criteria.
#' @param config_version A numeric value specifying the configuration version.
#' @param quantile_width A vector of numeric values representing the desired
#' quantiles. Passed to [tidybayes::median_qi()].
#' @param model A string specifying the model to be used.
#' @param report_date A string representing the report date. Formatted as
#' "YYYY-MM-DD".
#' @family config
#' @export
Config <- S7::new_class( # nolint: object_name_linter
  "Config",
  properties = list(
    job_id = S7::class_character,
    task_id = S7::class_character,
    min_reference_date = S7::class_character,
    max_reference_date = S7::class_character,
    report_date = S7::class_character,
    production_date = S7::class_character,
    disease = S7::class_character,
    geo_value = S7::class_character,
    geo_type = S7::class_character,
    seed = S7::class_integer,
    horizon = S7::class_integer,
    model = S7::new_property(S7::class_character, default = "EpiNow2"),
    config_version = S7::class_character,
    quantile_width = S7::new_property(S7::class_vector, default = c(0.5, 0.95)),
    data = S7::S7_class(Data()),
    # Using a list instead of an S7 object, because EpiNow2 expects a list, and
    # because it reduces changes to the pipeline code.
    # Would add default values, but Roxygen isn't happy about them yet.
    priors = S7::class_list,
    parameters = S7::S7_class(Parameters()),
    # Using a list instead of an S7 object, because stan expects a list, and
    # because it reduces changes to the pipeline code.
    # Would add default values, but Roxygen isn't happy about them yet.
    sampler_opts = S7::class_list,
    exclusions = S7::S7_class(Exclusions())
  )
)

#' Read JSON Configuration into Config Object
#'
#' Reads a JSON file from the specified path and converts it into a `Config`
#' object.
#'
#' @param config_path A string specifying the path to the JSON configuration
#' file.
#' @param optional_fields A list of strings specifying the optional fields in
#' the JSON file. If a field is not present in the JSON file, and is marked as
#' optional, it will be set to either the empty type (e.g. `chr(0)`), or NULL.
#' If a field is not present in the JSON file, and is not marked as optional, an
#' error will be thrown.
#' @return An instance of the `Config` class populated with the data from the
#' JSON file.
#' @family config
#' @export
read_json_into_config <- function(config_path, optional_fields) {
  # First, our hard coded, flattened, map from strings to Classes. If any new
  # subclasses are added above, they will also need to be added here. If we
  # create a more automated way to do this, we can remove this.
  str2class <- list(
    data = Data,
    parameters = Parameters,
    exclusions = Exclusions,
    generation_interval = GenerationInterval,
    delay_interval = DelayInterval,
    right_truncation = RightTruncation
  )

  # First, read the JSON file into a list
  raw_input <- jsonlite::read_json(config_path, simplifyVector = TRUE)

  # Check what top level properties were not in the raw input
  missing_properties <- setdiff(S7::prop_names(Config()), names(raw_input))
  # Remove any optional fields from the missing properties, give info message
  # about what is being given a default arg.
  not_need_but_missing <- intersect(optional_fields, missing_properties)
  if (length(not_need_but_missing) > 0) {
    cli::cli_alert_info(
      "Optional field{?s} not in config file: {.var {not_need_but_missing}}"
    )
  }
  missing_properties <- setdiff(missing_properties, optional_fields)
  # Error out if missing any fields
  if (length(missing_properties) > 0) {
    cli::cli_abort(c(
      "Propert{?y/ies} not in the config file: {.var {missing_properties}}"
    ))
  }

  inner <- function(raw_data, class_to_fill) {
    # For each property, check if it is a regular value, or an S7 object.
    # If it is an S7 object, we need to create an instance of that class, and do
    # all the same checks for properties that we did above. If not, just add it
    # to the config object.
    config <- class_to_fill()
    for (prop_name in names(raw_data)) {
      if (prop_name %in% names(str2class)) {
        # This is a class, call inner() again to recursively build it.
        S7::prop(config, prop_name) <- inner(
          raw_data[[prop_name]], str2class[[prop_name]]
        )
      } else if (!(prop_name %in% S7::prop_names(class_to_fill()))) {
        cli::cli_alert_info(
          "No Config field matching {.var {prop_name}}. Not using."
        )
      } else {
        # Else set it directly
        S7::prop(config, prop_name) <- raw_data[[prop_name]]
      }
    }
    config
  }

  inner(raw_input, Config)
}
