#!/bin/bash
#=============================================================================
# Sqoop 导出脚本 — 将Hive分析结果导出到MySQL
# 负责成员: C (大数据存储)
# 前置条件: MySQL中已执行 mysql_schema.sql 建表
#=============================================================================
set -e

MYSQL_HOST="localhost"
MYSQL_PORT="3306"
MYSQL_DB="movie_analysis"
MYSQL_USER="root"
MYSQL_PASS="root"

SQOOP_OPTS="--connect jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}?useSSL=false&characterEncoding=utf8mb4"
SQOOP_OPTS="${SQOOP_OPTS} --username ${MYSQL_USER} --password ${MYSQL_PASS}"

echo "[Sqoop] 开始导出分析结果到 MySQL..."

# 注意: 以下导出前需先在Hive中执行 02_analysis_queries.sql，并将结果存入临时表
# 或者使用 Sqoop 直接导出 Hive 查询结果

# --- 方式一: 导出Hive内部表 ---
sqoop export \
    ${SQOOP_OPTS} \
    --table rating_distribution \
    --export-dir /user/hive/warehouse/movie_db.db/ratings \
    --input-fields-terminated-by '\001' \
    --columns "score,count,percentage" \
    -m 1 2>&1 | tee sqoop_rating_dist.log

# --- 方式二: 使用Sqoop Eval直接执行Hive查询并导入 ---
# 每条分析结果单独处理

# 1. 评分分布
echo "[Sqoop] 导出: 评分分布..."
hive -e "USE movie_db;
INSERT OVERWRITE LOCAL DIRECTORY '/tmp/sqoop_export/rating_dist'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT CAST(rating AS INT), COUNT(*), ROUND(COUNT(*)*100.0/1000209, 2)
FROM ratings GROUP BY CAST(rating AS INT);"

mysql -u${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_DB} -e "
LOAD DATA LOCAL INFILE '/tmp/sqoop_export/rating_dist/000000_0'
INTO TABLE rating_distribution
FIELDS TERMINATED BY ','
(score, count, percentage);"

# 2. 热门电影TOP20
echo "[Sqoop] 导出: 热门电影TOP20..."
hive -e "USE movie_db;
INSERT OVERWRITE LOCAL DIRECTORY '/tmp/sqoop_export/top_movies'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT m.title, ROUND(AVG(r.rating),2), COUNT(*)
FROM ratings r JOIN movies m ON r.movie_id=m.movie_id
GROUP BY m.title HAVING COUNT(*)>=50
ORDER BY AVG(r.rating) DESC LIMIT 20;"

mysql -u${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_DB} -e "
LOAD DATA LOCAL INFILE '/tmp/sqoop_export/top_movies/000000_0'
INTO TABLE top_movies
FIELDS TERMINATED BY ','
(movie_name, avg_rating, rating_count);"

# 3. 类别统计
echo "[Sqoop] 导出: 电影类别统计..."
hive -e "USE movie_db;
INSERT OVERWRITE LOCAL DIRECTORY '/tmp/sqoop_export/genre_stats'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT g.genre, COUNT(DISTINCT g.movie_id), ROUND(AVG(r.rating),2), COUNT(r.rating)
FROM movie_genres g JOIN ratings r ON g.movie_id=r.movie_id
GROUP BY g.genre ORDER BY COUNT(DISTINCT g.movie_id) DESC;"

mysql -u${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_DB} -e "
LOAD DATA LOCAL INFILE '/tmp/sqoop_export/genre_stats/000000_0'
INTO TABLE genre_stats
FIELDS TERMINATED BY ','
(genre_name, movie_count, avg_rating, rating_count);"

# 4. 活跃用户TOP20
echo "[Sqoop] 导出: 活跃用户TOP20..."
hive -e "USE movie_db;
INSERT OVERWRITE LOCAL DIRECTORY '/tmp/sqoop_export/active_users'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT r.user_id, u.gender, u.age, u.occupation, COUNT(*), ROUND(AVG(r.rating),2)
FROM ratings r JOIN users u ON r.user_id=u.user_id
GROUP BY r.user_id, u.gender, u.age, u.occupation
ORDER BY COUNT(*) DESC LIMIT 20;"

mysql -u${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_DB} -e "
LOAD DATA LOCAL INFILE '/tmp/sqoop_export/active_users/000000_0'
INTO TABLE active_users
FIELDS TERMINATED BY ','
(user_id, gender, age, occupation, rating_count, avg_rating);"

# 5. 性别对比
echo "[Sqoop] 导出: 性别对比..."
hive -e "USE movie_db;
INSERT OVERWRITE LOCAL DIRECTORY '/tmp/sqoop_export/gender_comp'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT u.gender, COUNT(DISTINCT u.user_id), COUNT(r.rating),
       ROUND(AVG(r.rating),3),
       ROUND(SUM(CASE WHEN r.rating>=4 THEN 1 ELSE 0 END)*100.0/COUNT(*),2)
FROM users u JOIN ratings r ON u.user_id=r.user_id
GROUP BY u.gender;"

mysql -u${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_DB} -e "
LOAD DATA LOCAL INFILE '/tmp/sqoop_export/gender_comp/000000_0'
INTO TABLE gender_comparison
FIELDS TERMINATED BY ','
(gender, user_count, rating_count, avg_rating, high_rate_pct);"

# 6. 年龄段统计
echo "[Sqoop] 导出: 年龄段统计..."
hive -e "USE movie_db;
INSERT OVERWRITE LOCAL DIRECTORY '/tmp/sqoop_export/age_stats'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT u.age_group, COUNT(DISTINCT u.user_id), COUNT(r.rating), ROUND(AVG(r.rating),3)
FROM users u JOIN ratings r ON u.user_id=r.user_id
GROUP BY u.age_group;"

mysql -u${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_DB} -e "
LOAD DATA LOCAL INFILE '/tmp/sqoop_export/age_stats/000000_0'
INTO TABLE age_group_stats
FIELDS TERMINATED BY ','
(age_group, user_count, rating_count, avg_rating);"

# 7. 职业统计
echo "[Sqoop] 导出: 职业统计..."
hive -e "USE movie_db;
INSERT OVERWRITE LOCAL DIRECTORY '/tmp/sqoop_export/occ_stats'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT u.occupation, COUNT(DISTINCT u.user_id), COUNT(r.rating),
       ROUND(AVG(r.rating),3), ROUND(COUNT(r.rating)*1.0/COUNT(DISTINCT u.user_id),1)
FROM users u JOIN ratings r ON u.user_id=r.user_id
GROUP BY u.occupation ORDER BY COUNT(r.rating) DESC;"

mysql -u${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_DB} -e "
LOAD DATA LOCAL INFILE '/tmp/sqoop_export/occ_stats/000000_0'
INTO TABLE occupation_stats
FIELDS TERMINATED BY ','
(occupation, user_count, rating_count, avg_rating, rating_per_user);"

echo ""
echo "[Sqoop] 全部导出完成!"
echo "  共导出 7 张表到 MySQL movie_analysis 数据库"
echo ""
mysql -u${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_DB} -e "
SELECT TABLE_NAME, TABLE_ROWS
FROM information_schema.TABLES
WHERE TABLE_SCHEMA='movie_analysis';"
