library(DBI)
library(RPostgres)
library(cfbfastR)
library(dplyr)
library(DBI)
library(bit64)
library(secret)

source("helpers.R")
source("constants.R")

raw_pbp <- load_cfb_pbp(years)
pbp_2022 <- load_cfb_pbp(2022)

pbp <- raw_pbp %>%
  select(
    all_of(
      colnames(pbp_2022)
    )
  ) %>%
  mutate(
    game_id = as.character(as.integer64(game_id)),
    play_id = stringr::str_remove(
      as.character(as.integer64(id_play)),
      game_id
    ),
    .before = id_play
  ) %>%
  select(
    -id_play
  ) %>%
  mutate(
    game_id = as.integer(game_id),
    play_id = as.integer(play_id)
  ) %>%
  select(
    year,
    week,
    play_id,
    game_id,
    offense_play,
    defense_play,
    offense_score,
    defense_score,
    home,
    away,
    clock_minutes = clock.minutes,
    clock_seconds = clock.seconds,
    period
  )

dbCopy(
  db_url = get_secret("DB_URL"),
  schema = "raw",
  table = "pbp",
  data = pbp,
  drop = TRUE
)

conn <- connect_to_db()

dbExecute(
  conn,
  "
  CREATE INDEX index_raw_pbp_on_game_id_play_id
  ON raw.pbp
  (game_id, play_id)
  "
)
