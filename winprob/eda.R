library(dplyr)

source("helpers.R")

conn <- connect_to_db()

winners <- query(
  conn,
  '
  with last_plays as (
    select game_id, max(id_play) as id_play
    from pbp
    group by game_id
  ),
  game_winners as (
    select distinct
      lp.game_id,
      case
        when pbp.offense_score > pbp.defense_score then pbp.offense_play
        else pbp.defense_play
      end = pbp.home as home_win
    from last_plays lp
    join pbp using(game_id, id_play)
  ),
  clocks as (
    select game_id, id_play, "clock.minutes" as minutes, period
    from pbp
  )

  select gw.game_id, pbp.home, pbp.away, gw.home_win, wps.home_win_percentage
  from pbp
  join clocks c on c.period = 3 and c.minutes = 15 and c.game_id = pbp.game_id and c.id_play = pbp.id_play
  join game_winners gw using(game_id)
  join wps on pbp.game_id = wps.espn_game_id and wps.play_id = pbp.id_play
  '
)
