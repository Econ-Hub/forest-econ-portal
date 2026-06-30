# ------------------------------------------------------------------------------
# build_flow_analytics.R
#
# Pre-computes decision-support analytics for the West Boundary dashboard:
#   - Mean Annual Discharge (MAD) and 5% / 20% critical-flow thresholds
#   - Daily flows for drought analog years (2021, 2023) at the hero station
#   - Annual summer (Jul–Sep) 7-day low-flow series for long-term trend
#
# Requires: tidyhydat (one-time download_hydat()), dplyr, lubridate, zyp
# ------------------------------------------------------------------------------

suppressMessages({
  library(tidyhydat)
  library(dplyr)
  library(lubridate)
  library(zyp)
  library(Kendall)
})

hero   <- "08NN026"
analog <- c(2021L, 2023L)

dir.create("data", showWarnings = FALSE)

flows <- hy_daily_flows(station_number = hero) %>%
  filter(!is.na(Value)) %>%
  mutate(yday = yday(Date), year = year(Date), month = month(Date))

# --- Mean Annual Discharge (MAD) ---------------------------------------------
# MAD = mean of each year's mean daily discharge, averaged across all years.
annual <- flows %>%
  group_by(year) %>%
  summarise(annual_mean = mean(Value), .groups = "drop")

mad_row <- annual %>%
  summarise(
    STATION_NUMBER = hero,
    mad            = mean(annual_mean),
    n_years        = n(),
    start_year     = min(year),
    end_year       = max(year)
  ) %>%
  mutate(
    threshold_20pct = round(0.20 * mad, 3),
    threshold_05pct = round(0.05 * mad, 3),
    mad             = round(mad, 3)
  )

write.csv(mad_row, "data/flow_mad.csv", row.names = FALSE)

# --- Analog drought years (daily, aligned by calendar date) -------------------
analog_df <- flows %>%
  filter(year %in% analog) %>%
  transmute(
    STATION_NUMBER = hero,
    analog_year    = year,
    Date           = Date,
    yday           = yday,
    flow           = round(Value, 3)
  )
write.csv(analog_df, "data/flow_analog_years.csv", row.names = FALSE)

# --- Summer 7-day low-flow trend (Mann-Kendall) ------------------------------
summer_low <- flows %>%
  filter(month %in% 7:9) %>%
  arrange(Date) %>%
  mutate(roll7 = {
    v <- Value
    sapply(seq_along(v), function(i) if (i < 7) NA_real_ else mean(v[(i - 6):i]))
  }) %>%
  group_by(year) %>%
  summarise(summer_7day_min = min(roll7, na.rm = TRUE), .groups = "drop") %>%
  filter(is.finite(summer_7day_min))

mk <- Kendall::MannKendall(summer_low$summer_7day_min)
tv <- zyp.trend.vector(summer_low$summer_7day_min)
trend <- data.frame(
  STATION_NUMBER  = hero,
  metric          = "summer_7day_min_JAS",
  start_year      = min(summer_low$year),
  end_year        = max(summer_low$year),
  n_years         = nrow(summer_low),
  tau             = round(mk$tau, 3),
  p_value         = signif(mk$sl, 3),
  sen_slope_m3s_yr = round(unname(tv["trend"]), 4),
  direction       = ifelse(mk$sl < 0.05,
                           ifelse(unname(tv["trend"]) < 0, "Declining", "Increasing"),
                           "No significant trend")
)
write.csv(trend, "data/flow_trend.csv", row.names = FALSE)
write.csv(summer_low, "data/flow_summer_low.csv", row.names = FALSE)

message("Wrote data/flow_mad.csv, flow_analog_years.csv, flow_trend.csv, flow_summer_low.csv")
print(as.data.frame(mad_row))
print(as.data.frame(trend))
