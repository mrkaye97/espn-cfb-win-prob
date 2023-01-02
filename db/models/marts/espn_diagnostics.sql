{{ 
    config(
        indexes=[
            {'columns': ['game_id', 'play_id']},
        ]
    )
}}

WITH pbp AS (
    SELECT DISTINCT 
        season,
        week,
        play_id,
        game_id,
        home_team,
        away_team,
        plays_home_score AS home_score,
        plays_away_score AS away_score,
        clock_time_minutes AS clock_minutes,
        clock_time_seconds AS clock_seconds,
        plays_period_number AS period
    FROM {{ source("raw", "pbp") }}
),
last_plays AS (
    SELECT game_id, MAX(play_id) AS play_id
    FROM pbp
    GROUP BY game_id
),
game_winners as (
    SELECT DISTINCT
        lp.game_id,
        home_score > away_score AS home_win
    FROM last_plays lp
    JOIN pbp USING(game_id, play_id)
),
win_probs AS (
    SELECT DISTINCT game_id::INT, play_id::INT, home_win_prob
    FROM {{ source("raw", "espn_win_probs") }}
),
lines AS (
    SELECT game_id, home_moneyline, away_moneyline
    FROM {{ source("raw", "lines") }}
    WHERE home_moneyline IS NOT NULL OR away_moneyline IS NOT NULL
),
rankings AS (
    SELECT season, week, school, rank AS ap_ranking
    FROM {{ source("raw", "rankings") }}
    WHERE poll = 'AP Top 25'
)

SELECT DISTINCT
    p.game_id,
    p.play_id,
    p.home_team,
    p.away_team,
    p.clock_minutes AS clock__minutes_remaining,
    p.clock_seconds AS clock__seconds_remaining,
    p.period AS clock__period,
    p.home_score,
    p.away_score,
    wp.home_win_prob,
    gw.home_win,
    l.home_moneyline,
    l.away_moneyline,
    r1.ap_ranking AS teams__home_ranking,
    r2.ap_ranking AS teams__away_ranking
FROM pbp p
LEFT JOIN win_probs wp USING(game_id, play_id)
LEFT JOIN game_winners gw ON p.game_id = gw.game_id
LEFT JOIN lines l ON p.game_id = l.game_id
LEFT JOIN rankings r1 ON r1.season = p.season AND r1.week = p.week AND r1.school = p.home_team
LEFT JOIN rankings r2 ON r2.season = p.season AND r2.week = p.week AND r2.school = p.away_team
