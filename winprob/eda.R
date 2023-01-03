library(dplyr)
library(probably)
library(yardstick)
library(ggplot2)
library(ggthemes)
library(purrr)
library(svglite)

source("helpers.R")

conn <- connect_to_db()

result <- query(
  conn,
  "
  SELECT *
  FROM cfb.espn_diagnostics
  WHERE home_win_prob IS NOT NULL
  "
)

result <- result %>%
  group_by(game_id) %>%
  filter(
    all(home_score >= 0),
    all(away_score >= 0)
  ) %>%
  ungroup()

kickoff <- result %>%
  group_by(game_id) %>%
  slice_min(play_id, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  mutate(
    home_win = as.factor(home_win)
  )

halftime <- result %>%
  group_by(game_id) %>%
  filter(clock__period == 3) %>%
  slice_min(play_id, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  mutate(
    home_win = as.factor(home_win)
  )

generate_plot <- function(data, ...) {
  cal_plot_windowed(
    data,
    truth = home_win,
    estimate = home_win_prob,
    event_level = "second"
  ) +
    labs(..., caption = sprintf("Note: Total N size = %s", nrow(data))) +
    theme_fivethirtyeight() +
    theme(
      axis.title = element_text()
    )
}

generate_all_plots <- function(period) {
  data <- get(period)
  title_period <- switch(
    period,
    "kickoff" = "Kickoff",
    "halftime" = "Halftime",
    stop("Sorry, I don't recognize that data")
  )
  title <- sprintf("Calibration at %s", title_period)

  list(
    all = generate_plot(data, title = title),
    ranked = generate_plot(
      filter(
        data,
        !is.na(teams__home_ranking) | !is.na(teams__away_ranking)
      ),
      title = title,
      subtitle = "All ranked teams"
    ),
    top_15 = generate_plot(
      filter(
        data,
        teams__home_ranking <= 15 | teams__away_ranking <= 15
      ),
      title = title,
      subtitle = "Only including teams in the top 15"
    )
  )
}

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

generate_diagnostic <- function(mins_out) {
  result %>%
    filter(
      home_win_prob > .99 | home_win_prob < 0.01,
      (clock__minutes_remaining == mins_out) & (clock__period == 4)
    ) %>%
    group_by(game_id, home_favored = home_win_prob > 0.5) %>%
    summarize(
      mean_home_win_prob = mean(home_win_prob),
      home_win = first(home_win),
      .groups = "drop"
    ) %>%
    mutate(
      is_unlikely_outcome = (mean_home_win_prob > 0.5 & !home_win) | (mean_home_win_prob < 0.5 & home_win)
    ) %>%
    summarize(
      mins_remaining = mins_out,
      unlikely_event_prob_given = 100 * (1 - mean(ifelse(mean_home_win_prob < 0.5, 1 - mean_home_win_prob, mean_home_win_prob))),
      unlikely_event_actually_happens = 100 * (sum(is_unlikely_outcome) / n()),
      n = n()
    )
}

map_dfr(1:15, generate_diagnostic)


kickoff %>%
  filter(
    !is.na(teams__home_ranking) & !is.na(teams__away_ranking)
  ) %>%
  roc_auc(
    truth = home_win,
    estimate = home_win_prob,
    event_level = "second"
  )

money_line_to_odds <- function(line) {
  ifelse(
    line < 0,
    abs(line) / (100 + abs(line)),
    100 / (100 + line)
  )
}

brier_score <- function(truth, estimate) {
  mean((truth - estimate)^2)
}

brier_skill_score <- function(truth, estimate, ref) {
  ref_bs <- brier_score(truth, ref)
  estimate_bs <- brier_score(truth, estimate)

  1 - (estimate_bs / ref_bs)
}

line_odds <- halftime %>%
  filter(
    !is.na(home_moneyline),
    !is.na(away_moneyline)
  ) %>%
  mutate(
    home_moneyline_odds = money_line_to_odds(home_moneyline),
    away_moneyline_odds = 1 - money_line_to_odds(away_moneyline),
    avg_line_odds = (home_moneyline_odds + away_moneyline_odds) / 2
  )



line_odds %>%
  filter(!is.na(avg_line_odds)) %>%
  select(
    game_id,
    play_id,
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
    truth = home_win,
    estimate = estimate,
    event_level = "second",
    group = estimator
  )
