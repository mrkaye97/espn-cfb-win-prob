remove_negative_score_games <- function(data) {
  data |>
    dplyr::group_by(game_id) |>
    dplyr::filter(
      all(home_score >= 0),
      all(away_score >= 0)
    ) |>
    dplyr::ungroup()
}

generate_timestamps <- function(data) {
  data |>
    dplyr::mutate(
      time_counter = as.integer(
        paste(
          clock__period,
          stringr::str_pad(15 - clock__minutes_remaining, 2, "left", "0"),
          stringr::str_pad(60 - clock__seconds_remaining, 2, "left", "0"),
          sep = ""
        )
      ),
      .after = game_id
    )
}

.enforce_rough_monotonicity_impl <- function(data, col, order_by = "time_counter") {
  if (nrow(data) == 0L) return(data)

  previous <- dplyr::lag(
    x = data[[col]],
    n = 1,
    order_by = data[[order_by]]
  )

  if (all(data[[col]] >= previous, na.rm = TRUE)) {
    data
  } else if (sum(data[[col]] < previous, na.rm = TRUE) == 1L) {
    ix <- data[col] >= previous | is.na(previous)
    data[ix,]
  } else {
    tibble::tibble()
  }
}

enforce_rough_monotonicity <- function(data) {
  data |>
    dplyr::group_split(game_id) |>
    purrr::map_dfr(
      ~ {
        .x |>
          .enforce_rough_monotonicity_impl("home_score") |>
          .enforce_rough_monotonicity_impl("away_score")
      }
    )
}

attach_line_odds <- function(data) {
  data |>
    filter(
      !is.na(home_moneyline),
      !is.na(away_moneyline)
    ) |>
      mutate(
        home_moneyline_odds = money_line_to_odds(home_moneyline),
        away_moneyline_odds = 1 - money_line_to_odds(away_moneyline),
        avg_line_odds = (home_moneyline_odds + away_moneyline_odds) / 2
      )
}
