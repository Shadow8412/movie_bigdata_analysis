USE movie_db;
SELECT u.occupation,
    COUNT(DISTINCT u.user_id) AS user_count,
    COUNT(r.rating) AS rating_count,
    ROUND(AVG(r.rating), 3) AS avg_rating,
    ROUND(COUNT(r.rating) * 1.0 / COUNT(DISTINCT u.user_id), 1) AS rating_per_user
FROM users u
JOIN ratings r ON u.user_id = r.user_id
GROUP BY u.occupation
ORDER BY rating_count DESC
LIMIT 20;
DROP TABLE IF EXISTS tmp_ranked;
DROP TABLE IF EXISTS tmp_age_genre_stats;
