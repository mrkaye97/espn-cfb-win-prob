library(cfbfastR)
library(dplyr)
library(purrr)
library(furrr)
library(dplyr)

source("helpers.R")
source("constants.R")

conn <- connect_to_db()

games <- query(
  conn,
  "select distinct game_id from pbp where year = 2022"
)$game_id

safely_get_wp <- safely(get_espn_wp_college)

plan(multisession, workers = 8)

wps <- future_map_dfr(
  games,
  ~ safely_get_wp(.x) |>
    pluck("result") |>
    tibble() |>
    mutate(
      espn_game_id = as.integer(espn_game_id),
      play_id = as.numeric(play_id)
    ),
  .options = furrr_options(stdout = FALSE)
)

dbCopy(
  conn,
  "wps",
  wps,
  truncate = TRUE
)
