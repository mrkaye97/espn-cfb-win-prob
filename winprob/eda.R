library(dplyr)
library(probably)
library(yardstick)

source("helpers.R")

conn <- connect_to_db()

result <- query(
  conn,
  "
  SELECT *
  FROM cfb.pbp
  WHERE home_win_prob IS NOT NULL
  "
)

first_win_prob <- result %>%
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

probably::cal_plot_breaks(
  first_win_prob,
  truth = home_win,
  estimate = home_win_prob,
  event_level = "second",
  num_breaks = 20
)

probably::cal_plot_breaks(
  halftime,
  truth = home_win,
  estimate = home_win_prob,
  event_level = "second",
  num_breaks = 20
)

roc_auc(
  first_win_prob,
  truth = home_win,
  estimate = home_win_prob,
  event_level = "second"
)

yardstick::mn_log_loss(
  first_win_prob,
  truth = home_win,
  estimate = home_win_prob,
  event_level = "second"
)

top_teams <- c(
  ## B1G
  "Michigan",
  "Ohio State",

  ## ACC
  "Clemson",

  ## SEC
  "Alabama",
  "LSU",
  "Georgia",
  "Tennessee",

  ## Big XII
  "Oklahoma",
  "TCU",
  "Texas",

  ## PAC 12
  "Oregon",
  "Utah",
  "USC"
)

first_win_prob %>%
  filter(
    teams__home %in% top_teams |
    teams__away %in% top_teams
  ) %>%
  roc_auc(
    truth = home_win,
    estimate = home_win_prob,
    event_level = "second"
  )

first_win_prob %>%
  filter(
    teams__home %in% top_teams |
    teams__away %in% top_teams
  ) %>%
  cal_plot_windowed(
    truth = home_win,
    estimate = home_win_prob,
    event_level = "second",
    conf_level = 0.80
  )
