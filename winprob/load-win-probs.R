library(cfbfastR)
library(dplyr)
library(purrr)
library(furrr)
library(dplyr)
library(bit64)
library(secret)
library(DBI)

source("helpers.R")

conn <- connect_to_db()

games <- query(
  conn,
  "select distinct game_id from raw.pbp"
)$game_id

safely_get_wp <- safely(get_espn_wp_college)

plan(multisession, workers = 10)

wps <- future_map_dfr(
  games,
  ~ {
    result <- safely_get_wp(.x) |>
      pluck("result")

    if (nrow(result) == 0) {
      return(
        tibble()
      )
    }

    result %>%
      tibble() %>%
      transmute(
        game_id = as.character(as.integer64(espn_game_id)),
        play_id = stringr::str_remove(
          as.character(as.integer64(play_id)),
          game_id
        ),
        home_win_prob = home_win_percentage
      )
  }
)

dbCopy(
  db_url = get_secret("DB_URL"),
  schema = "raw",
  table = "espn_win_probs",
  data = wps,
  fields = list(
    game_id = "INT",
    play_id = "INT",
    home_win_prob = "FLOAT"
  ),
  drop = TRUE
)

dbExecute(
  conn,
  "
  CREATE INDEX index_raw_wps_on_game_id_play_id
  ON raw.espn_win_probs
  (game_id, play_id)
  "
)
