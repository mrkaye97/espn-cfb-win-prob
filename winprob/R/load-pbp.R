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
library(stringr)

source("R/helpers.R")
source("R/constants.R")

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
    data <- tryCatch({espn_cfb_pbp(.x)}, error = function(e) tibble())

    if (nrow(data) == 0L) {
      return(tibble())
    }

    mutate(
      data,
      game_id = .x,
      play_id = as.integer(str_sub(plays_id, nchar(.x) + 1, nchar(plays_id))),
      clock_time_minutes = ms(plays_clock_display_value) %>% minute(),
      clock_time_seconds = ms(plays_clock_display_value) %>% second(),
    )
  },
  .options = furrr_options(seed = NULL)
)

plan(sequential)

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
