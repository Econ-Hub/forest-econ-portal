# ------------------------------------------------------------------------------
# build_flow_normals.R
#
# Pre-computes the historical streamflow baselines used by the West Boundary
# water-security dashboard (water-security.qmd) from the Water Survey of Canada
# HYDAT database. Run this occasionally (e.g. once a year, after the spring
# HYDAT release) to refresh the committed CSVs in /data.
#
# Why precompute? The full HYDAT database is ~1.3 GB. By summarising it down to
# small CSVs here, the published dashboard only needs to fetch the lightweight
# *live* readings at render time and never has to download HYDAT. RDKB can
# regenerate the baselines at any time by re-running this script.
#
# Requirements: install.packages(c("tidyhydat","dplyr","lubridate"))
# First-time HYDAT download: tidyhydat::download_hydat(ask = FALSE)
# ------------------------------------------------------------------------------

suppressMessages({
  library(tidyhydat)
  library(dplyr)
  library(lubridate)
})

# Project-area stations (Kettle River from Midway upstream, RDKB Area E)
stations <- c(
  "08NN026", # KETTLE RIVER NEAR WESTBRIDGE (main stem, hero station)
  "08NN003", # WEST KETTLE RIVER AT WESTBRIDGE
  "08NN015", # WEST KETTLE RIVER NEAR MCCULLOCH
  "08NN019", # TRAPPING CREEK NEAR THE MOUTH
  "08NN029"  # BOUNDARY CREEK NEAR BOUNDARY FALLS (short record)
)

dir.create("data", showWarnings = FALSE)

# --- Station metadata + period of record -------------------------------------
flows <- hy_daily_flows(station_number = stations) %>%
  filter(!is.na(Value)) %>%
  mutate(yday = yday(Date), year = year(Date))

por <- flows %>%
  group_by(STATION_NUMBER) %>%
  summarise(start_year = min(year), end_year = max(year),
            n_years = n_distinct(year), .groups = "drop")

meta <- hy_stations(station_number = stations) %>%
  select(STATION_NUMBER, STATION_NAME, LATITUDE, LONGITUDE, DRAINAGE_AREA_GROSS) %>%
  left_join(por, by = "STATION_NUMBER")

write.csv(meta, "data/stations.csv", row.names = FALSE)

# --- Smoothed day-of-year percentile envelope --------------------------------
# For each day of year we pool all daily flows within a +/- `win` day window
# across every year of record, then take percentiles. This produces a smooth
# "normal range" envelope rather than a noisy single-day estimate.
win <- 7
qs  <- c(p10 = 0.10, p25 = 0.25, p50 = 0.50, p75 = 0.75, p90 = 0.90)

# Only build a seasonal-normal envelope for stations with a meaningful record
# length; short-record stations are still shown live but without a baseline.
normal_stations <- por$STATION_NUMBER[por$n_years >= 10]

normals <- lapply(normal_stations, function(st) {
  d <- filter(flows, STATION_NUMBER == st)
  if (nrow(d) == 0) return(NULL)
  rows <- lapply(1:366, function(dd) {
    dist <- pmin(abs(d$yday - dd), 366 - abs(d$yday - dd))
    v <- d$Value[dist <= win]
    if (length(v) < 10) return(NULL)
    qq <- quantile(v, probs = qs, na.rm = TRUE, names = FALSE)
    data.frame(STATION_NUMBER = st, yday = dd,
               p10 = qq[1], p25 = qq[2], p50 = qq[3],
               p75 = qq[4], p90 = qq[5], n = length(v))
  })
  do.call(rbind, rows)
}) %>% bind_rows()

normals <- normals %>%
  mutate(across(c(p10, p25, p50, p75, p90), ~ round(.x, 3)))
write.csv(normals, "data/flow_normals.csv", row.names = FALSE)

# --- Monthly climatology (for the seasonality view) --------------------------
monthly <- flows %>%
  group_by(STATION_NUMBER, year, month = month(Date)) %>%
  summarise(monthly_mean = round(mean(Value), 3), .groups = "drop")
write.csv(monthly, "data/flow_monthly.csv", row.names = FALSE)

message("Wrote data/stations.csv, data/flow_normals.csv, data/flow_monthly.csv")
