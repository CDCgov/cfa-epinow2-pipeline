if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  "Microsoft365R", # for accessing onedrive #https://stackoverflow.com/questions/28048979/accessing-excel-file-from-sharepoint-with-r
  "readxl", # for reading excel files
  "optparse",
  "lubridate",
  "tidyr",
  "dplyr",
  "readr",
  "AzureStor"
)
source("../R/azure.R")


option_list <- list(
  make_option(c("-d", "--dates"),
    type = "character", default = gsub("-", "", today(tzone = "UTC")),
    help = "Reports Date in yyyymmdd format", metavar = "character"
  )
)
opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)
# Get All Files Names to Download and Parse
date_names <- opt$dates



read_process_excel_func <- function(
    sheet_name,
    pathogen,
    file_name,
    report_date) {
  # sheet_name="Rt_Review_COVID"
  # pathogen="covid"
  # file_name=fname
  df <- read_excel(paste0(file_name), # may neeed to edit path where saved
    sheet = sheet_name,
    skip = 3
  )
  colnames(df) <- c("state", "dates_affected", "observed volume", "expected volume", "initial_thoughts", "state_abb", "review_1_decision", "reviewer_2_decision", "final_decision", "drop_dates", "additional_reasoning")
  df <- data.frame(separate_rows(df, 10, sep = "\\|")) |>
    filter(!is.na(state)) |>
    mutate(
      report_date = report_date,
      pathogen = pathogen
    ) |>
    select("report_date", "state", "state_abb", "pathogen", "review_1_decision", "reviewer_2_decision", "final_decision", "drop_dates")
  return(df)
}



create_point_exclusions_from_rt_review_xslx <- function(
    dates # yyyymmdd format
    ) {
  # Connect to Sharepoint  via Microsoft365R library
  # get_business_onedrive(auth_type = "device_code")  #Run and the browser opens to log into sharepoint
  site <- get_sharepoint_site(auth_type = "device_code", "OD-OCoS-Center for Forecasting and Outbreak Analytics") # Provide team name here
  drv <- site$get_drive("Documents") # Set drive to Documents (vs Wiki)
  Rt_review_path <- "General/02 - Predict/Real Time Monitoring (RTM) Branch/Nowcasting and Natural History/Rt/NSSP-Rt/Rt_Review_Notes/Review_Decisions/"


  for (report_date in dates) {
    # report_date="20240922"
    fname <- paste0("Rt_Review_", report_date, ".xlsx")
    # report_date = readr::parse_number(fname)
    drv$get_item(paste0(Rt_review_path, fname))$download(
      dest = paste0(fname),
      overwrite = TRUE
    )
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
    # Overall Rt_review machine readable format
    combined_df <- rbind(covid_df, influenza_df)
    if (file.exists(paste0(fname))) {
      # Delete file if it exists
      file.remove(paste0(fname))
    }
    # Further processing
    combined_df <- combined_df |>
      mutate(
        reference_date = ymd(drop_dates),
        report_date = ymd(report_date),
        geo_value = state_abb,
        pathogen = case_when(pathogen == "influenza" ~ "Influenza",
          pathogen == "covid" ~ "COVID-19",
          .default = as.character(pathogen)
        )
      )

    # point exclusions in outlier.csv format
    point_exclusions <- combined_df |>
      filter(!is.na(drop_dates)) |>
      mutate(
        raw_confirm = NA,
        clean_confirm = NA
      ) |>
      select(reference_date, report_date, "state" = "geo_value", "disease" = "pathogen", raw_confirm, clean_confirm)

    cont <- fetch_blob_container("nssp-etl-2")

    storage_write_csv(
      cont = cont,
      object = point_exclusions,
      file = file.path("outliers", paste0(ymd(report_date), ".csv"))
    )
  }
}


create_point_exclusions_from_rt_review_xslx(dates = date_names)
