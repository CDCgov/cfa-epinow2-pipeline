# Local edits
if (!require("pacman")) install.packages("pacman"); library(pacman) 

pacman::p_load(
  "dplyr",
  "optparse",
  "lubridate",
  "readxl",
  "tidyr",
  "AzureStor",
  "cli",
)
source("R/azure.R")

option_list <- list(
  optparse::make_option(
    c("-d", "--dates"),
    type = "character",
    default = gsub(
      "-",
      "",
      lubridate::today(tzone = "UTC")
    ),
    help = "Reports Date in yyyymmdd format",
    metavar = "character"
  )
)
opt_parser <- optparse::OptionParser(option_list = option_list)
opt <- optparse::parse_args(opt_parser)
# Get All Files Names to Download and Parse
date_names <- opt$dates

read_process_excel_func <- function(
  sheet_name,
  pathogen,
  file_name,
  report_date
) {
  df <- readxl::read_excel(
    paste0(file_name), # path where saved
    sheet = sheet_name,
    skip = 3,
    col_names = c(
      "state",
      "dates_affected",
      "observed volume",
      "expected volume",
      "initial_thoughts",
      "state_abb",
      "review_1_decision",
      "reviewer_2_decision",
      "final_decision",
      "drop_dates",
      "additional_reasoning"
    )
  )
  df <- df |> dplyr::mutate(drop_dates = as.character(drop_dates))
  df <- data.frame(tidyr::separate_rows(df, 10, sep = "\\|")) |>
    dplyr::filter(!is.na(state)) |>
    dplyr::mutate(
      report_date = report_date,
      pathogen = pathogen
    ) |>
    dplyr::select(
      "report_date",
      "state",
      "state_abb",
      "pathogen",
      "review_1_decision",
      "reviewer_2_decision",
      "final_decision",
      "drop_dates"
    )
  return(df)
}


create_pt_excl_from_rt_xslx <- function(dates) {
  for (report_date in dates) {
    username= Sys.info()[['user']]
    fname <- paste0("~/Downloads/Rt_Review_", report_date, ".xlsx") # /home/",username,"/
    # read and process the COVID sheet
    covid_df <- read_process_excel_func(
      sheet_name = "Rt_Review_COVID",
      pathogen = "covid",
      file_name = fname,
      report_date = report_date
    )
    # read and process the Influenza sheet
    influenza_df <- read_process_excel_func(
      sheet_name = "Rt_Review_Influenza",
      pathogen = "influenza",
      file_name = fname,
      report_date = report_date
    )
    # read and process the RSV sheet
    rsv_df <- read_process_excel_func(
      sheet_name = "Rt_Review_RSV",
      pathogen = "rsv",
      file_name = fname,
      report_date = report_date
    )
    # Overall Rt_review machine readable format
    combined_df <- rbind(covid_df, influenza_df, rsv_df)
    if (file.exists(paste0(fname))) {
      # Delete file if it exists
      file.remove(paste0(fname))
    }
    # Further processing
    combined_df <- combined_df |>
      dplyr::mutate(
        reference_date = lubridate::ymd(drop_dates),
        report_date = lubridate::ymd(report_date),
        geo_value = state_abb,
        pathogen = dplyr::case_when(
          pathogen == "rsv" ~ "RSV",
          pathogen == "influenza" ~ "Influenza",
          pathogen == "covid" ~ "COVID-19",
          .default = as.character(pathogen)
        )
      )

    # point exclusions in outlier.csv format
    point_exclusions <- combined_df |>
      dplyr::filter(!is.na(drop_dates)) |>
      dplyr::filter(!is.na(reference_date)) |>
      dplyr::mutate(
        raw_confirm = NA,
        clean_confirm = NA
      ) |>
      dplyr::select(
        reference_date,
        report_date,
        "state" = "geo_value",
        "disease" = "pathogen"
      )
    #container_name <- "nssp-etl"
    #cont <- fetch_blob_container(container_name)

    empty_df <- function(df2) {
      all(df2 == "")
    }

    # if (empty_df(point_exclusions)) {
    #   cli::cli_alert_info(
    #     "This CSV contains empty values. No output file created."
    #   )
    # } else {
    #   cli::cli_alert_info(
    #     "saving {lubridate::ymd(report_date)}.csv in
    #     {container_name}/outliers-v2"
    #   )
    #   AzureStor::storage_write_csv(
    #     cont = cont,
    #     object = point_exclusions,
    #     file = file.path(
    #       "outliers-v2",
    #       paste0(lubridate::ymd(report_date), ".csv")
    #     ),
    #     quote = FALSE,
    #     row.names = FALSE
    #   )
    # }
    write.csv(point_exclusions,
    paste0("~/Downloads/",lubridate::ymd(report_date), ".csv"),
    row.names = FALSE )


    #### State exclusions #####
    state_exclusions <- combined_df |>
      dplyr::filter(
        final_decision %in%
          c(
            "Exclude State (Data)",
            "Exclude State (Model)",
            "Exclude State"
          )
      ) |>
      dplyr::mutate(
        type = dplyr::case_when(
          final_decision == "Exclude State (Data)" ~ "Data",
          final_decision == "Exclude State (Model)" ~ "Model"
        )
      ) |>
      dplyr::select(state_abb, pathogen, type)

    # container_name <- "nssp-etl"
    # cont <- fetch_blob_container(container_name)
    file <- paste0(lubridate::ymd(report_date), "_state_exclusions.csv")
    # cli::cli_alert_info(
    #   "saving {file} in {container_name}/state_exclusions"
    # )
    # AzureStor::storage_write_csv(
    #   cont = cont,
    #   object = state_exclusions,
    #   file = file.path(
    #     "state_exclusions",
    #     file
    #   ),
    #   quote = FALSE,
    #   row.names = FALSE
    # )

    write.csv(state_exclusions,paste0("~/Downloads/",file ),row.names = FALSE)
  }
}


create_pt_excl_from_rt_xslx(dates = date_names)
