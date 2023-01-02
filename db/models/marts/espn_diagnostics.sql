{{ 
    config(
        indexes=[
            {'columns': ['game_id', 'play_id']},
        ]
    )
}}

WITH pbp AS (
    SELECT DISTINCT 
        year,
        season,
        week,
        play_id,
        game_id,
        offense_play,
        defense_play,
        offense_score,
        defense_score,
        home,
        away,
        "clock.minutes" AS clock_minutes,
        "clock.seconds" AS clock_seconds,
        period
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
        CASE
            WHEN pbp.offense_score > pbp.defense_score THEN pbp.offense_play
            ELSE pbp.defense_play
        END = pbp.home AS home_win
    FROM last_plays lp
    JOIN pbp USING(game_id, play_id)
),
home_away_scores AS (
    SELECT DISTINCT
        game_id,
        play_id,
        CASE WHEN offense_play = home THEN offense_score ELSE defense_score END AS home_score,
        CASE WHEN offense_play = away THEN offense_score ELSE defense_score END AS away_score
    FROM pbp
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
    p.home AS teams__home,
    p.away AS teams__away,
    p.clock_minutes AS clock__minutes_remaining,
    p.clock_seconds AS clock__seconds_remaining,
    p.period AS clock__period,
    s.home_score AS scores__home,
    s.away_score AS scores__away,
    wp.home_win_prob,
    gw.home_win,
    l.home_moneyline,
    l.away_moneyline,
    r1.ap_ranking AS teams__home_ranking,
    r2.ap_ranking AS teams__away_ranking
FROM pbp p
LEFT JOIN home_away_scores s USING(game_id, play_id)
LEFT JOIN win_probs wp USING(game_id, play_id)
LEFT JOIN game_winners gw ON p.game_id = gw.game_id
LEFT JOIN lines l ON p.game_id = l.game_id
LEFT JOIN rankings r1 ON r1.season = p.season AND r1.week = p.week AND r1.school = p.home
LEFT JOIN rankings r2 ON r2.season = p.season AND r2.week = p.week AND r2.school = p.away
