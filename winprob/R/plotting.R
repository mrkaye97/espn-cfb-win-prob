generate_plot <- function(data, ...) {
  probably::cal_plot_windowed(
    data,
    truth = home_win_fct,
    estimate = home_win_prob,
    event_level = "second"
  ) +
    ggplot2::labs(..., caption = sprintf("Note: Total N size = %s", nrow(data))) +
    ggthemes::theme_fivethirtyeight() +
    ggplot2::theme(
      axis.title = ggplot2::element_text()
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
      dplyr::filter(
        data,
        !is.na(teams__home_ranking) | !is.na(teams__away_ranking)
      ),
      title = title,
      subtitle = "All ranked teams"
    ),
    top_15 = generate_plot(
      dplyr::filter(
        data,
        teams__home_ranking <= 15 | teams__away_ranking <= 15
      ),
      title = title,
      subtitle = "Only including teams in the top 15"
    )
  )
}
