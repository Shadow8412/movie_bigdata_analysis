-- 修复版 4.6.2 + 4.7 查询 (兼容 Hive 2.1.0，使用临时表)
USE movie_db;

-- ==================== 4.6.2 各年龄段偏好电影类别TOP3 ====================
SELECT '===== 4.6.2 各年龄段偏好电影类别TOP3 =====' AS info;

DROP TABLE IF EXISTS tmp_age_genre_stats;
CREATE TABLE tmp_age_genre_stats AS
SELECT
    u.age_group,
    g.genre,
    COUNT(*) AS genre_rating_count
FROM ratings r
JOIN users u ON r.user_id = u.user_id
JOIN movie_genres g ON r.movie_id = g.movie_id
GROUP BY u.age_group, g.genre;

SELECT age_group, genre, genre_rating_count
FROM (
    SELECT age_group, genre, genre_rating_count,
        ROW_NUMBER() OVER (PARTITION BY age_group ORDER BY genre_rating_count DESC) AS rnk
    FROM tmp_age_genre_stats
) t
WHERE t.rnk <= 3
ORDER BY
    CASE age_group
        WHEN 'Under18' THEN 1 WHEN '19-25' THEN 2 WHEN '26-35' THEN 3
        WHEN '36-45' THEN 4 WHEN '46-55' THEN 5 WHEN '56+' THEN 6
    END, t.rnk;

DROP TABLE IF EXISTS tmp_age_genre_stats;


-- ==================== 4.7 不同职业用户评分习惯 ====================
SELECT '===== 4.7 各职业用户评分统计 =====' AS info;
SELECT
    u.occupation,
    COUNT(DISTINCT u.user_id) AS user_count,
    COUNT(r.rating)           AS rating_count,
    ROUND(AVG(r.rating), 3)   AS avg_rating,
    ROUND(COUNT(r.rating) * 1.0 / COUNT(DISTINCT u.user_id), 1) AS rating_per_user
FROM users u
JOIN ratings r ON u.user_id = r.user_id
GROUP BY u.occupation
ORDER BY rating_count DESC
LIMIT 20;
