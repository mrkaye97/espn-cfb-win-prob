library(dplyr)
library(probably)
library(yardstick)
library(ggplot2)
library(ggthemes)
library(purrr)
library(svglite)

Sys.setenv(R_SECRET_VAULT = "vault")

source("R/helpers.R")
source("R/data-wrangling.R")
source("R/diagnostics.R")
source("R/plotting.R")

conn <- connect_to_db()

raw <- query(
  conn,
  "
  SELECT *
  FROM cfb.espn_diagnostics
  WHERE home_win_prob IS NOT NULL
  "
)

clean <- raw %>%
  remove_negative_score_games() %>%
  generate_timestamps() %>%
  enforce_rough_monotonicity() %>%
  mutate(
    home_win_fct = as.factor(home_win)
  )

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
        device = "svg"
      )
    )
  }
)


UPPER_BOUND <- 0.98
LOWER_BOUND <- 0.02
## Define an extreme prediction as any game where ESPN gave >98% with > 5 mins to go
## and a point spread of <= 3 scores (24 pts)
extreme_prediction_games <- clean %>%
  filter(
    home_win_prob > UPPER_BOUND | home_win_prob < LOWER_BOUND,
    (clock__period < 4) |
    (clock__period == 4 & clock__minutes_remaining >= 5),
    abs(home_score - away_score) <= 24
  ) %>%
  group_by(
    game_id,
    extreme_away_win_prob = home_win_prob < LOWER_BOUND,
    extreme_home_win_prob = home_win_prob > UPPER_BOUND
  ) %>%
  summarize(
    mean_home_win_prob = mean(home_win_prob),
    home_win = first(home_win),
    .groups = "drop"
  ) %>%
  filter(
    extreme_away_win_prob | extreme_home_win_prob
  )

kickoff %>%
  filter(
  ) %>%
  group_by(
    num_ranked = case_when(
      !is.na(teams__home_ranking) & !is.na(teams__away_ranking) ~ "both",
      !is.na(teams__home_ranking) | !is.na(teams__away_ranking) ~ "one",
      TRUE ~ "none"
    )
  ) %>%
  roc_auc(
    truth = home_win_fct,
    estimate = home_win_prob,
    event_level = "second"
  )

kickoff %>%
  group_by(
    num_ranked = case_when(
      !is.na(teams__home_ranking) & !is.na(teams__away_ranking) ~ "both",
      !is.na(teams__home_ranking) | !is.na(teams__away_ranking) ~ "one",
      TRUE ~ "none"
    )
  ) %>%
  cal_plot_windowed(
    truth = home_win_fct,
    estimate = home_win_prob,
    event_level = "second",
    conf_level = 0.80
  )

line_odds <- attach_line_odds(kickoff)

line_odds %>%
  filter(!is.na(avg_line_odds)) %>%
  select(
    game_id,
    time_counter,
    avg_line_odds,
    home_win,
    home_win_prob
  ) %>%
  summarize(
    bs_line = brier_score(
      as.numeric(home_win) - 1,
      avg_line_odds
    ),
    bs_espn = brier_score(
      as.numeric(home_win) - 1,
      home_win_prob
    ),
    bss = brier_skill_score(
      as.numeric(home_win) - 1,
      home_win_prob,
      avg_line_odds
    )
  )

line_odds %>%
  tidyr::pivot_longer(
    cols = c(home_win_prob, avg_line_odds),
    names_to = "estimator",
    values_to = "estimate"
  ) %>%
  cal_plot_windowed(
    truth = home_win_fct,
    estimate = estimate,
    event_level = "second",
    group = estimator
  )
