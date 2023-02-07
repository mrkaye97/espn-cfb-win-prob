library(dplyr)
library(probably)
library(yardstick)
library(ggplot2)
library(ggthemes)
library(purrr)
library(svglite)

source("R/common/helpers.R")
source("R/common/data-wrangling.R")
source("R/common/plotting.R")
source("R/common/load-clean-data.R")

kickoff <- clean %>%
  group_by(game_id) %>%
  slice_min(time_counter, n = 1, with_ties = FALSE) %>%
  ungroup()

halftime <- clean %>%
  group_by(game_id) %>%
  filter(clock__period == 3) %>%
  slice_min(time_counter, n = 1, with_ties = FALSE) %>%
  ungroup()

walk(
  c("kickoff", "halftime"),
  function(period) {

    plots <- generate_all_plots(period)
    dir.create(sprintf("../plots/calibration/%s", period), recursive = TRUE)

    imap(
      plots,
      ~ ggsave(
        sprintf("../plots/calibration/%s/%s.svg", period, .y),
        .x,
        device = "svg",
        width = 12,
        height = 10
      )
    )
  }
)

kickoff %>%
  group_by(
    Ranked = case_when(
      !is.na(teams__home_ranking) & !is.na(teams__away_ranking) ~ "Both",
      !is.na(teams__home_ranking) | !is.na(teams__away_ranking) ~ "One",
      TRUE ~ "Neither"
    )
  ) %>%
  cal_plot_windowed(
    truth = home_win_fct,
    estimate = home_win_prob,
    event_level = "second",
    conf_level = 0.80
  ) %>%
  style_plot(
    title = "Calibration at Kickoff",
    subtitle = "Grouped by how many - if any - teams were ranked (either both, neither, or one of the two)"
  ) %>%
  ggsave(
    filename = "../plots/calibration/kickoff/grouped-by-num-ranked.svg",
    plot = .,
    device = "svg",
    width = 12,
    height = 10
  )

boot <- function() {
  kickoff %>%
    filter(home_win_prob < 0.05) %>%
    slice_sample(., n = nrow(.), replace = TRUE) %>%
    count(home_win) %>%
    mutate(
      prop = n / sum(n)
    ) %>%
    filter(home_win) %>%
    pull(prop)
}

purrr::map_dbl(
  1:1000,
  boot()
) %>%
  quantile(c(0.025, 0.975))

