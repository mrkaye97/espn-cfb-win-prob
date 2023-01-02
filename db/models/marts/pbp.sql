{{ 
    config(
        indexes=[
            {'columns': ['game_id', 'play_id']},
        ]
    )
}}

WITH pbp AS (
    SELECT *
    FROM {{ source("raw", "pbp") }}
),
clocks AS (
    SELECT 
        game_id, 
        play_id, 
        "clock.minutes" AS minutes, 
        "clock.seconds" AS seconds, 
        period
    FROM pbp
),
last_plays AS (
    SELECT game_id, MAX(play_id) AS play_id
    FROM pbp
    GROUP BY game_id
),
game_winners as (
    SELECT DISTINCT
        lp.game_id,
        CASE
            WHEN pbp.offense_score > pbp.defense_score THEN pbp.offense_play
            ELSE pbp.defense_play
        END = pbp.home AS home_win
    FROM last_plays lp
    JOIN pbp USING(play_id)
),
home_away_scores AS (
    SELECT
      play_id,
      CASE WHEN offense_play = home THEN offense_score ELSE defense_score END AS home_score,
      CASE WHEN offense_play = away THEN offense_score ELSE defense_score END AS away_score
    FROM pbp
),
win_probs AS (
    SELECT DISTINCT play_id::BIGINT, home_win_prob
    FROM {{ source("raw", "espn_win_probs") }}
)

SELECT DISTINCT
    p.game_id,
    p.play_id,
    p.home AS teams__home,
    p.away AS teams__away,
    c.minutes AS clock__minutes_remaining,
    c.seconds AS clock__seconds_remaining,
    c.period AS clock__period,
    s.home_score AS scores__home,
    s.away_score AS scores__away,
    wp.home_win_prob,
    gw.home_win
FROM pbp p
LEFT JOIN clocks c USING(play_id)
LEFT JOIN home_away_scores s USING(play_id)
LEFT JOIN game_winners gw ON p.game_id = gw.game_id
LEFT JOIN win_probs wp ON wp.play_id::BIGINT = p.play_id::BIGINT
ORDER BY game_id, play_id, clock__period, clock__minutes_remaining DESC, clock__seconds_remaining DESC