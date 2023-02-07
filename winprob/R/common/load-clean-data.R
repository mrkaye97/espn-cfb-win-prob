source("R/common/helpers.R")
source("R/common/data-wrangling.R")
source("R/common/plotting.R")

.conn <- connect_to_db()

.raw <- query(
  .conn,
  "
  SELECT *
  FROM cfb.espn_diagnostics
  WHERE home_win_prob IS NOT NULL
  "
)

clean <- .raw |>
  remove_negative_score_games() |>
  generate_timestamps() |>
  enforce_rough_monotonicity() |>
  dplyr::mutate(
    home_win_fct = as.factor(home_win)
  )

DBI::dbDisconnect(.conn)
