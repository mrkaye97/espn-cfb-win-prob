library(DBI)
library(RPostgres)
library(cfbfastR)
library(dplyr)
library(DBI)
library(bit64)
library(secret)
library(purrr)
library(furrr)
library(lubridate)

source("helpers.R")
source("constants.R")

Sys.setenv(CFBD_API_KEY = get_secret("CFBD_API_KEY"))

game_ids <- map(
  years,
  ~ cfbd_game_info(year = .x)$game_id
) %>%
  flatten_int()

plan(multisession, workers = 10)

pbp <- future_map_dfr(
  game_ids,
  ~ {
    espn_cfb_pbp(.x) %>%
      mutate(game_id = .x) %>%
      transmute(
        season,
        week,
        game_id,
        play_id = as.integer(stringr::str_sub(plays_id, nchar(.x) + 1, nchar(plays_id))),
        home_team,
        away_team,
        home_score = plays_home_score,
        away_score = plays_away_score,
        wall_clock_time = plays_wallclock,
        clock_time_minutes = ms(plays_clock_display_value) %>% minute(),
        clock_time_seconds = ms(plays_clock_display_value) %>% second(),
        clock_period = plays_period_number
      )
  }
)

dbCopy(
  db_url = get_secret("DB_URL"),
  schema = "raw",
  table = "pbp",
  data = pbp,
  drop = TRUE
)

conn <- connect_to_db()

dbCreateIndex(
  conn,
  "pbp",
  c("game_id", "play_id")
)
