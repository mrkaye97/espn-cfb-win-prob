`%||%` <- rlang::`%||%`

get_espn_wp_college <- function(espn_game_id) {
  espn_wp <- data.frame()
  tryCatch(
    expr = {
      espn_wp <-
        httr::GET(url = glue::glue("http://site.api.espn.com/apis/site/v2/sports/football/college-football/summary?event={espn_game_id}")) %>%
        httr::content(as = "text", encoding = "UTF-8") %>%
        jsonlite::fromJSON(flatten = TRUE) %>%
        purrr::pluck("winprobability") %>%
        janitor::clean_names() %>%
        dplyr::mutate(
          espn_game_id = stringr::str_sub(play_id, end = stringr::str_length(espn_game_id))
        ) %>%
        dplyr::select(espn_game_id, play_id, home_win_percentage)
      message(glue::glue("{Sys.time()}: Scraping ESPN wp data for GameID '{espn_game_id}'..."))
    },
    error = function(e) {
      message(glue::glue("{Sys.time()}: GameID '{espn_game_id}' invalid or no wp data available!"))
    }
  )

  espn_wp
}

dbCopy <- function(conn, name, value, drop = FALSE, fields = NULL) {

  if (isTRUE(drop)) {
    rlang::inform(sprintf("Dropping %s", name))
    DBI::dbExecute(
      conn,
      sprintf(
        "DROP TABLE IF EXISTS %s",
        name
      )
    )
    rlang::inform(sprintf("Dropped %s", name))
  }

  if (isFALSE(DBI::dbExistsTable(conn, name))) {
    DBI::dbCreateTable(conn, name, fields %||% value)
  }

  tmp <- tempfile(fileext = ".csv")

  readr::write_csv(
    value,
    tmp,
    na = ""
  )

  DBI::dbExecute(
    conn,
    sprintf(
      "COPY %s FROM '%s' CSV HEADER",
      name,
      tmp
    )
  )
}

query <- function(conn, statement) {
  result <- DBI::dbGetQuery(
    conn,
    statement
  )

  tibble::tibble(result)
}

dbCreateIndex <- function(conn, name, cols) {
  ix_name <- paste(
    "index",
    name,
    "on",
    paste(cols, collapse = "_"),
    sep = "_"
  )
  ix <- paste(cols, collapse = ", ")

  DBI::dbExecute(
    conn,
    sprintf(
      "
      CREATE INDEX %s
      ON %s
      (%s)
      ",
      ix_name,
      name,
      ix
    )
  )
}

connect_to_db <- function() {
  DBI::dbConnect(
    RPostgres::Postgres(),
    dbname = "cfb"
  )
}
