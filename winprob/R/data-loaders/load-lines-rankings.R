library(DBI)
library(cfbfastR)
library(dplyr)
library(DBI)
library(secret)
library(purrr)

source("R/common/helpers.R")
source("R/common/constants.R")

Sys.setenv(CFBD_API_KEY = get_secret("CFBD_API_KEY"))

lines <- map_dfr(years, ~ cfbd_betting_lines(year = .x))
rankings <- map_dfr(years, ~ cfbd_rankings(year = .x))

dbCopy(
  db_url = get_secret("DB_URL"),
  schema = "raw",
  table = "lines",
  data = lines,
  drop = TRUE
)

dbCopy(
  db_url = get_secret("DB_URL"),
  schema = "raw",
  table = "rankings",
  data = rankings,
  drop = TRUE
)

conn <- connect_to_db()

dbCreateIndex(
  conn,
  "lines",
  "game_id"
)

dbCreateIndex(
  conn,
  "rankings",
  "school"
)

