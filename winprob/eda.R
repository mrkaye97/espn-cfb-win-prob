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
    select game_id, id_play, "clock.minutes" as minutes, "clock.seconds" as seconds, period
    from pbp
  ),
  scores as (
    select
      game_id, id_play,
      case when offense_play = home then offense_score else defense_score end as home_score,
      case when offense_play = away then offense_score else defense_score end as away_score
    from pbp
  ),
  out as (
    select
      pbp.game_id, pbp.id_play,
      pbp.home, pbp.away,
      c.period, c.minutes, c.seconds,
      gw.home_win, wps.home_win_percentage
    from pbp
    join clocks c on c.id_play = pbp.id_play
    join game_winners gw on pbp.game_id = gw.game_id
    join wps on wps.play_id = pbp.id_play
    join scores s on s.id_play = pbp.id_play
  )

  select * from clocks

  '
)
