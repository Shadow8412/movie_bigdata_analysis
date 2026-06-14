-- =============================================================================
-- HiveQL 大数据分析查询
-- 负责成员: D (大数据分析)
-- 数据集: MovieLens 1M (6040用户, 3883电影, 1000209评分)
-- =============================================================================
USE movie_db;

-- ==================== 4.1 电影评分整体分布统计 ====================
-- 统计1-5分各有评分数量，了解整体评分倾向
SELECT '===== 4.1 评分整体分布 =====' AS info;
SELECT
    CAST(rating AS INT) AS score,
    COUNT(*)            AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM ratings
GROUP BY CAST(rating AS INT)
ORDER BY score;


-- ==================== 4.2 评分最高 TOP20 电影 ====================
-- 条件: 评分人数 >= 50，按平均评分降序
SELECT '===== 4.2 评分最高TOP20电影 =====' AS info;
SELECT
    m.title       AS movie_name,
    ROUND(AVG(r.rating), 2) AS avg_rating,
    COUNT(*)      AS rating_count
FROM ratings r
JOIN movies m ON r.movie_id = m.movie_id
GROUP BY m.title
HAVING COUNT(*) >= 50
ORDER BY avg_rating DESC
LIMIT 20;


-- ==================== 4.3 各电影类别数量与平均评分 ====================
-- 分析哪种类型的电影最受欢迎
SELECT '===== 4.3 电影类别统计 =====' AS info;
SELECT
    g.genre                AS genre_name,
    COUNT(DISTINCT g.movie_id) AS movie_count,
    ROUND(AVG(r.rating), 2)    AS avg_rating,
    COUNT(r.rating)        AS rating_count
FROM movie_genres g
JOIN ratings r ON g.movie_id = r.movie_id
GROUP BY g.genre
ORDER BY movie_count DESC;


-- ==================== 4.4 最活跃用户 TOP20 ====================
-- 按评分数量排名
SELECT '===== 4.4 最活跃用户TOP20 =====' AS info;
SELECT
    r.user_id,
    u.gender,
    u.age,
    u.occupation,
    COUNT(*)    AS rating_count,
    ROUND(AVG(r.rating), 2) AS avg_user_rating
FROM ratings r
JOIN users u ON r.user_id = u.user_id
GROUP BY r.user_id, u.gender, u.age, u.occupation
ORDER BY rating_count DESC
LIMIT 20;


-- ==================== 4.5 男女用户评分偏好对比 ====================
-- 不同性别用户的平均评分、评分数量对比
SELECT '===== 4.5 男女用户评分对比 =====' AS info;
SELECT
    u.gender,
    COUNT(DISTINCT u.user_id) AS user_count,
    COUNT(r.rating)           AS rating_count,
    ROUND(AVG(r.rating), 3)   AS avg_rating,
    ROUND(SUM(CASE WHEN r.rating >= 4 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS high_rate_pct
FROM users u
JOIN ratings r ON u.user_id = r.user_id
GROUP BY u.gender;


-- ==================== 4.6 不同年龄段用户观影偏好 ====================
-- 各年龄段用户的评分数量和平均分
SELECT '===== 4.6 各年龄段用户评分统计 =====' AS info;
SELECT
    u.age_group,
    COUNT(DISTINCT u.user_id) AS user_count,
    COUNT(r.rating)           AS rating_count,
    ROUND(AVG(r.rating), 3)   AS avg_rating
FROM users u
JOIN ratings r ON u.user_id = r.user_id
GROUP BY u.age_group
ORDER BY
    CASE u.age_group
        WHEN 'Under18' THEN 1
        WHEN '19-25'   THEN 2
        WHEN '26-35'   THEN 3
        WHEN '36-45'   THEN 4
        WHEN '46-55'   THEN 5
        WHEN '56+'     THEN 6
    END;

-- 各年龄段偏好的电影类别 TOP3
SELECT '===== 4.6.2 各年龄段偏好电影类别TOP3 =====' AS info;
SELECT age_group, genre, genre_rating_count
FROM (
    SELECT
        u.age_group,
        g.genre,
        COUNT(*) AS genre_rating_count,
        ROW_NUMBER() OVER (PARTITION BY u.age_group ORDER BY COUNT(*) DESC) AS rn
    FROM ratings r
    JOIN users u ON r.user_id = u.user_id
    JOIN movie_genres g ON r.movie_id = g.movie_id
    GROUP BY u.age_group, g.genre
) t
WHERE rn <= 3
ORDER BY
    CASE age_group
        WHEN 'Under18' THEN 1 WHEN '19-25' THEN 2 WHEN '26-35' THEN 3
        WHEN '36-45' THEN 4 WHEN '46-55' THEN 5 WHEN '56+' THEN 6
    END, rn;


-- ==================== 4.7 不同职业用户评分习惯 ====================
-- 各职业用户的平均评分和观影量
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


-- ==================== 4.8 综合仪表板数据 ====================
-- 总览数据
SELECT '===== 4.8 数据总览 =====' AS info;
SELECT
    (SELECT COUNT(*) FROM movies)      AS total_movies,
    (SELECT COUNT(*) FROM ratings)     AS total_ratings,
    (SELECT COUNT(*) FROM users)       AS total_users,
    (SELECT ROUND(AVG(rating), 3) FROM ratings) AS overall_avg_rating,
    (SELECT COUNT(DISTINCT genre) FROM movie_genres) AS genre_count;
