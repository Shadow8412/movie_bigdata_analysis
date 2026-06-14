USE movie_db;

-- 1. 评分分布
INSERT OVERWRITE LOCAL DIRECTORY '/tmp/hive_export/rating_dist'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT CAST(rating AS INT) AS score, COUNT(*) AS cnt,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM ratings GROUP BY CAST(rating AS INT) ORDER BY score;

-- 2. TOP20电影
INSERT OVERWRITE LOCAL DIRECTORY '/tmp/hive_export/top_movies'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT m.title, ROUND(AVG(r.rating),2) AS avg_rating, COUNT(*) AS rating_count
FROM ratings r JOIN movies m ON r.movie_id=m.movie_id
GROUP BY m.title HAVING COUNT(*)>=50 ORDER BY avg_rating DESC LIMIT 20;

-- 3. 类别统计
INSERT OVERWRITE LOCAL DIRECTORY '/tmp/hive_export/genre_stats'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT g.genre, COUNT(DISTINCT g.movie_id) AS movie_count,
    ROUND(AVG(r.rating),2) AS avg_rating, COUNT(r.rating) AS rating_count
FROM movie_genres g JOIN ratings r ON g.movie_id=r.movie_id
GROUP BY g.genre ORDER BY movie_count DESC;
