USE movie_db;
-- 2. TOP20电影导出
INSERT OVERWRITE LOCAL DIRECTORY '/tmp/hive_export/top20'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT m.title, ROUND(AVG(r.rating),2), COUNT(*)
FROM ratings r JOIN movies m ON r.movie_id=m.movie_id
GROUP BY m.title HAVING COUNT(*)>=50 ORDER BY AVG(r.rating) DESC LIMIT 20;

-- 3. 类别统计导出
INSERT OVERWRITE LOCAL DIRECTORY '/tmp/hive_export/genre'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT g.genre, COUNT(DISTINCT g.movie_id), ROUND(AVG(r.rating),2), COUNT(r.rating)
FROM movie_genres g JOIN ratings r ON g.movie_id=r.movie_id
GROUP BY g.genre ORDER BY COUNT(DISTINCT g.movie_id) DESC;
