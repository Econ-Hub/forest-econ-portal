# ------------------------------------------------------------------------------
# build_gw_normals.R
#
# Pre-computes historical groundwater-level baselines for the West Boundary
# water-security dashboard from the B.C. Provincial Groundwater Observation Well
# Network (PGOWN). Run occasionally to refresh the committed CSVs in /data.
#
# Data source: per-well CSVs published by B.C. ENV at
#   https://www.env.gov.bc.ca/wsd/data_searches/obswell/map/data/OW<id>-data.csv
# "Value" is depth to water below ground surface (m); a LARGER value means a
# LOWER water table (drier). Distributed under the Open Government Licence - BC.
#
# Requirements: install.packages(c("readr","dplyr","lubridate"))
# ------------------------------------------------------------------------------

suppressMessages({
  library(readr)
  library(dplyr)
  library(lubridate)
})

base_url <- "https://www.env.gov.bc.ca/wsd/data_searches/obswell/map/data/"

# Observation wells in / adjacent to the project area (Kettle valley aquifers)
wells <- tribble(
  ~well,    ~location,                  ~aquifer,                  ~lat,     ~lng,
  "OW217",  "Grand Forks (Richmond Ave.)", "Grand Forks (Aquifer 158)", 49.0301, -118.4377,
  "OW306",  "Beaverdell",               "West Kettle valley",      49.4253, -119.0828,
  "OW444",  "Midway",                   "Kettle valley",           49.0093, -118.7726
)

dir.create("data", showWarnings = FALSE)

read_well <- function(id) {
  url <- paste0(base_url, id, "-data.csv")
  message("Downloading ", url)
  df <- readr::read_csv(url, show_col_types = FALSE,
                        col_types = cols(Time = col_character(), Value = col_double(),
                                         .default = col_character()))
  df %>%
    transmute(well = id,
              datetime = ymd_hm(Time, quiet = TRUE),
              depth = Value) %>%
    filter(!is.na(datetime), !is.na(depth)) %>%
    mutate(Date = as.Date(datetime)) %>%
    group_by(well, Date) %>%
    summarise(depth = mean(depth), .groups = "drop") %>%
    mutate(yday = yday(Date), year = year(Date))
}

all_daily <- bind_rows(lapply(wells$well, read_well))

por <- all_daily %>%
  group_by(well) %>%
  summarise(start_year = min(year), end_year = max(year),
            n_years = n_distinct(year), .groups = "drop")

meta <- wells %>% left_join(por, by = "well")
write.csv(meta, "data/gw_wells.csv", row.names = FALSE)

# Smoothed day-of-year depth percentiles (+/- 7-day window across all years).
win <- 7
qs  <- c(p10 = 0.10, p25 = 0.25, p50 = 0.50, p75 = 0.75, p90 = 0.90)
keep <- por$well[por$n_years >= 5]

normals <- lapply(keep, function(w) {
  d <- filter(all_daily, well == w)
  rows <- lapply(1:366, function(dd) {
    dist <- pmin(abs(d$yday - dd), 366 - abs(d$yday - dd))
    v <- d$depth[dist <= win]
    if (length(v) < 10) return(NULL)
    qq <- quantile(v, probs = qs, na.rm = TRUE, names = FALSE)
    data.frame(well = w, yday = dd,
               p10 = qq[1], p25 = qq[2], p50 = qq[3], p75 = qq[4], p90 = qq[5],
               n = length(v))
  })
  do.call(rbind, rows)
}) %>% bind_rows() %>%
  mutate(across(c(p10, p25, p50, p75, p90), ~ round(.x, 3)))

write.csv(normals, "data/gw_normals.csv", row.names = FALSE)
message("Wrote data/gw_wells.csv and data/gw_normals.csv")
print(as.data.frame(meta))
