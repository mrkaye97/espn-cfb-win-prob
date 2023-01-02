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

dbCopy <- function(db_url = secret::get_secret("DB_URL"), schema, table, data, drop = FALSE, fields = NULL) {

  conn <- connect_to_db(url = db_url)

  if (isTRUE(drop)) {
    rlang::inform(sprintf("Dropping %s.%s", schema, table))
    DBI::dbExecute(
      conn,
      sprintf(
        "DROP TABLE IF EXISTS %s.%s",
        schema,
        table
      )
    )
    rlang::inform(sprintf("Dropped %s.%s", schema, table))
  }

  DBI::dbExecute(
    conn,
    sprintf("CREATE SCHEMA IF NOT EXISTS %s", schema)
  )

  if (isFALSE(DBI::dbExistsTable(conn, DBI::Id(schema = schema, table = table)))) {
    DBI::dbCreateTable(conn, DBI::Id(schema = schema, table = table), rlang::`%||%`(fields, data))
  }

  DBI::dbDisconnect(conn)

  tmp <- tempfile(fileext = ".csv")

  readr::write_csv(
    data,
    tmp,
    na = ""
  )

  url <- secret::get_secret("DB_URL")

  cmd <- glue::glue(
    "
    psql \\
    -d \"{url}\" \\
    -c \"\\COPY {schema}.{table} FROM '{tmp}' WITH DELIMITER ',' CSV HEADER\"
    "
  )

  system(cmd)

  invisible()
}

query <- function(conn, statement) {
  result <- DBI::dbGetQuery(
    conn,
    statement
  )

  tibble::tibble(result)
}

dbCreateIndex <- function(conn, table, cols) {
  ix_name <- paste(
    "index",
    table,
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
      ON raw.%s
      (%s)
      ",
      ix_name,
      table,
      ix
    )
  )
}

generate_db_conn_components <- function(url) {
  httr::parse_url(url)
}

connect_to_db <- function(url = secret::get_secret("DB_URL")) {
  components <- generate_db_conn_components(url)

  DBI::dbConnect(
    RPostgres::Postgres(),
    user = components$username,
    password = components$password,
    host = components$hostname,
    port = 5432,
    dbname = components$scheme
  )
}
