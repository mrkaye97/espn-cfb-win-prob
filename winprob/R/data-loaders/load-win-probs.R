library(cfbfastR)
library(dplyr)
library(purrr)
library(furrr)
library(dplyr)
library(bit64)
library(secret)
library(DBI)

source("R/common/helpers.R")

conn <- connect_to_db()

games <- query(
  conn,
  "SELECT DISTINCT game_id FROM raw.pbp"
)$game_id

plan(multisession, workers = 10)

wps <- future_map(
  games,
  ~ {
    result <- get_espn_wp_college(.x)

    if (nrow(result$result) > 0) {
      result$result <- result$result %>%
        transmute(
          game_id = as.character(as.integer64(espn_game_id)),
          play_id = stringr::str_remove(
            as.character(as.integer64(play_id)),
            game_id
          ),
          home_win_prob = home_win_percentage
        )
    }

    return(result)
  }
)

successes <- wps %>%
  keep(
    ~ nrow(.x$result) > 0
  ) %>%
  map_dfr(
    ~ .x$result
)

failures <- keep(
    wps,
    ~ nrow(.x$result) == 0 && .x$response$status_code != 200 && .x$response$status_code != 404
)

dbCopy(
  db_url = get_secret("DB_URL"),
  schema = "raw",
  table = "espn_win_probs",
  data = successes,
  fields = list(
    game_id = "INT",
    play_id = "INT",
    home_win_prob = "FLOAT"
  ),
  drop = TRUE
)

dbCreateIndex(
  conn,
  "espn_win_probs",
  c("game_id", "play_id")
)
