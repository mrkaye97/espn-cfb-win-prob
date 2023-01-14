library(dplyr)
library(purrr)

source("R/load-clean-data.R")

LOWER_BOUND <- 0.02
UPPER_BOUND <- 0.98
## Define an extreme prediction as any game where ESPN gave >98% with > 5 mins to go
## and a point spread of <= 3 scores (24 pts)

extract_extreme_result_games <- function(ranked = c("both", "one", "neither", "all")) {
  ranked <- match.arg(ranked)

  clean %>%
    filter(
      if (ranked == "both")
        !(is.na(teams__away_ranking) | is.na(teams__home_ranking))
      else if (ranked == "one")
        xor(is.na(teams__away_ranking), is.na(teams__home_ranking))
      else if (ranked == "neither")
        (is.na(teams__away_ranking) & is.na(teams__home_ranking))
      else
        TRUE,
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
      home_rank = first(teams__home_ranking),
      away_rank = first(teams__away_ranking),
      mean_home_win_prob = mean(home_win_prob),
      home_win = first(home_win),
      .groups = "drop"
    ) %>%
    filter(
      extreme_away_win_prob | extreme_home_win_prob
    )
}

get_prop_odd_result <- function(data) {
  data %>%
    count(
      is_odd_result = (mean_home_win_prob < 0.5 & home_win) |
        (mean_home_win_prob > 0.5 & !home_win)
    ) %>%
    mutate(prop = n / sum(n)) %>%
    filter(is_odd_result) %>%
    pull(prop)
}

boot_extreme_outcome <- function(data, ix) {
  if (ix %% 100 == 0) message("Bootstrap iteration ", ix)
  ix <- sample(
    1:nrow(data),
    size = nrow(data),
    replace = TRUE
  )

  result <- get_prop_odd_result(data[ix, ])

  if (is_empty(result)) result <- 0

  result
}

c("both", "one", "neither", "all") %>%
  set_names() %>%
  map(extract_extreme_result_games) %>%
  imap_dfr(
    ~ {
      odd_result_prop <- get_prop_odd_result(.x)
      ci <- purrr::map_dbl(
        1:1000,
        function(ix) boot_extreme_outcome(.x, ix)
      ) %>%
        quantile(
          probs = c(0.025, 0.975)
        )

      list(
        ranked = .y,
        proportion = paste0(round(100 * odd_result_prop, 2), "%"),
        lo = paste0(round(100 * ci[1], 2), "%"),
        hi = paste0(round(100 * ci[2], 2), "%"),
        n = nrow(.x)
      )
    }
  ) %>%
  write.csv(
    file = "../tables/extreme-event-cis/cis.csv",
    row.names = FALSE
  )


