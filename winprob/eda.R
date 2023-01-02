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
  f <- if (nrow(data) > 1000) cal_plot_breaks else cal_plot_windowed
  f(
    data,
    truth = home_win,
    estimate = home_win_prob,
    event_level = "second",
    num_breaks = 20
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

