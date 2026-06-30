# ------------------------------------------------------------------------------
# build_snow_normals.R
#
# Pre-computes SWE baselines for Grano Creek ASWS (2E07P) — the Boundary
# Region's real-time snow station (Kettle River watershed). Pulls from the
# B.C. Data Catalogue via bcdata; committed CSVs keep the published site light.
#
# Requirements: install.packages("bcdata")
# ------------------------------------------------------------------------------

suppressMessages({
  library(dplyr)
  library(lubridate)
  library(readr)
})

if (!requireNamespace("bcdata", quietly = TRUE)) {
  stop("Install bcdata: install.packages('bcdata')")
}
library(bcdata)

snow_id   <- "2E07P"
col_pat   <- "2E07P"
snow_name <- "Grano Creek"

dir.create("data", showWarnings = FALSE)

message("Downloading daily SWE archive from B.C. Data Catalogue...")
archive <- bcdc_get_data(
  "5e7acd31-b242-4f09-8a64-000af872d68f",
  resource = "666b7263-6111-488c-89aa-7480031f74cd"
)
swe_col <- grep(col_pat, names(archive), value = TRUE)[1]
if (is.na(swe_col)) stop("Column for ", snow_id, " not found in archive")

daily <- archive %>%
  transmute(Date = as.Date(`DATE(UTC)`), swe = .data[[swe_col]]) %>%
  filter(!is.na(Date), !is.na(swe), swe >= 0)

# Append current water-year readings (may extend past archive)
message("Fetching current water-year SWE...")
tryCatch({
  cur <- bcdc_get_data(
    "3a34bdd1-61b2-4687-8b55-c5db5e13ff50",
    resource = "fe591e21-7ffd-45f4-b3b3-2291e4a6de15"
  )
  cur_col <- grep(col_pat, names(cur), value = TRUE)[1]
  if (!is.na(cur_col)) {
    cur_daily <- cur %>%
      transmute(datetime = `DATE(UTC)`, swe = .data[[cur_col]]) %>%
      mutate(hour = hour(datetime)) %>%
      filter(hour == 16) %>%
      transmute(Date = as.Date(datetime), swe) %>%
      filter(!is.na(swe), swe >= 0)
    daily <- bind_rows(daily, cur_daily) %>%
      distinct(Date, .keep_all = TRUE) %>%
      arrange(Date)
  }
}, error = function(e) message("Current-year SWE fetch skipped: ", conditionMessage(e)))

daily <- daily %>%
  mutate(
    wy    = ifelse(month(Date) >= 10, year(Date) + 1L, year(Date)),
    wyday = as.integer(Date - as.Date(paste0(wy - 1L, "-10-01"))) + 1L
  )

meta <- data.frame(
  station_id   = snow_id,
  station_name = snow_name,
  latitude     = 49.55197,
  longitude    = -118.6773,
  elevation_m  = 1870,
  start_year   = min(year(daily$Date)),
  end_year     = max(year(daily$Date)),
  n_years      = n_distinct(daily$wy),
  stringsAsFactors = FALSE
)
write.csv(meta, "data/snow_station.csv", row.names = FALSE)

win <- 7
qs  <- c(p10 = 0.10, p25 = 0.25, p50 = 0.50, p75 = 0.75, p90 = 0.90)

normals <- lapply(1:366, function(dd) {
  dist <- pmin(abs(daily$wyday - dd), 366 - abs(daily$wyday - dd))
  v <- daily$swe[dist <= win]
  if (length(v) < 10) return(NULL)
  qq <- quantile(v, probs = qs, na.rm = TRUE, names = FALSE)
  data.frame(wyday = dd, p10 = qq[1], p25 = qq[2], p50 = qq[3],
             p75 = qq[4], p90 = qq[5], n = length(v))
}) %>% bind_rows() %>%
  mutate(across(c(p10, p25, p50, p75, p90), ~ round(.x, 1)))

write.csv(normals, "data/snow_normals.csv", row.names = FALSE)

cur_wy <- max(daily$wy)
write.csv(
  daily %>% filter(wy == cur_wy) %>% select(Date, wyday, swe) %>% arrange(Date),
  "data/snow_current_wy.csv", row.names = FALSE
)

message("Wrote data/snow_station.csv, snow_normals.csv, snow_current_wy.csv (WY ", cur_wy, ")")
print(meta)
