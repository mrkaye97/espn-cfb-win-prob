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
    play_id = as.character(as.integer64(id_play)),
    .before = id_play
  ) %>%
  select(
    -id_play
  )

dbCopy(
  db_url = get_secret("DB_URL"),
  "pbp",
  pbp,
  drop = FALSE
)

dbExecute(
  conn,
  "
  ALTER TABLE pbp
  ALTER COLUMN play_id
  TYPE BIGINT
  USING play_id::BIGINT
  "
)

dbCreateIndex(
  conn,
  "pbp",
  c("game_id", "play_id")
)
