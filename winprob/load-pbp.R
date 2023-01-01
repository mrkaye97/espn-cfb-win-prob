library(DBI)
library(RPostgres)
library(cfbfastR)
library(dplyr)

source("helpers.R")
source("constants.R")

conn <- dbConnect(
  Postgres(),
  dbname = "cfb"
)

pbp <- load_cfb_pbp(years)
pbp_2022 <- load_cfb_pbp(2022)

pbp <- select(
  pbp,
  all_of(
    colnames(pbp_2022)
  )
)

dbCopy(
  conn,
  "pbp",
  pbp,
  truncate = TRUE
)
