-- =============================================================================
-- Hive DDL 建表脚本
-- 负责成员: C (大数据存储)
-- 功能: 创建外部表 → 创建内部表 → 加载数据
-- =============================================================================

-- ==================== 1. 创建数据库 ====================
CREATE DATABASE IF NOT EXISTS movie_db
COMMENT 'MovieLens电影评分分析数据库';
USE movie_db;

-- ==================== 2. 创建外部表 (关联HDFS原始CSV) ====================

-- 2.1 电影外部表
DROP TABLE IF EXISTS movies_ext;
CREATE EXTERNAL TABLE movies_ext (
    movie_id    INT,
    title       STRING,
    title_full  STRING,
    genres_raw  STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/hive/warehouse/movie_db.db/raw_movies'
TBLPROPERTIES ("skip.header.line.count"="1");

-- 2.2 评分外部表
DROP TABLE IF EXISTS ratings_ext;
CREATE EXTERNAL TABLE ratings_ext (
    user_id    INT,
    movie_id   INT,
    rating     DOUBLE,
    `timestamp`  BIGINT
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/hive/warehouse/movie_db.db/raw_ratings'
TBLPROPERTIES ("skip.header.line.count"="1");

-- 2.3 用户外部表
DROP TABLE IF EXISTS users_ext;
CREATE EXTERNAL TABLE users_ext (
    user_id       INT,
    gender        STRING,
    age           INT,
    age_group     STRING,
    occupation_id INT,
    occupation    STRING,
    zipcode       STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/hive/warehouse/movie_db.db/raw_users'
TBLPROPERTIES ("skip.header.line.count"="1");

-- 2.4 电影类别外部表 (拆分的Genres)
DROP TABLE IF EXISTS movie_genres_ext;
CREATE EXTERNAL TABLE movie_genres_ext (
    movie_id INT,
    title    STRING,
    genre    STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/hive/warehouse/movie_db.db/raw_genres'
TBLPROPERTIES ("skip.header.line.count"="1");

-- ==================== 3. 创建内部表 (ORC格式, 优化查询性能) ====================

-- 3.1 电影内部表
DROP TABLE IF EXISTS movies;
CREATE TABLE movies (
    movie_id   INT,
    title      STRING,
    title_full STRING,
    genres_raw STRING
)
STORED AS ORC;

INSERT INTO TABLE movies
SELECT DISTINCT movie_id, title, title_full, genres_raw
FROM movies_ext
WHERE movie_id IS NOT NULL;

-- 3.2 评分内部表
DROP TABLE IF EXISTS ratings;
CREATE TABLE ratings (
    user_id   INT,
    movie_id  INT,
    rating    DOUBLE,
    ts        BIGINT
)
STORED AS ORC;

INSERT INTO TABLE ratings
SELECT DISTINCT user_id, movie_id, rating, `timestamp`
FROM ratings_ext
WHERE user_id IS NOT NULL AND movie_id IS NOT NULL;

-- 3.3 用户内部表
DROP TABLE IF EXISTS users;
CREATE TABLE users (
    user_id       INT,
    gender        STRING,
    age           INT,
    age_group     STRING,
    occupation_id INT,
    occupation    STRING,
    zipcode       STRING
)
STORED AS ORC;

INSERT INTO TABLE users
SELECT DISTINCT user_id, gender, age, age_group, occupation_id, occupation, zipcode
FROM users_ext
WHERE user_id IS NOT NULL;

-- 3.4 电影类别内部表
DROP TABLE IF EXISTS movie_genres;
CREATE TABLE movie_genres (
    movie_id INT,
    title    STRING,
    genre    STRING
)
STORED AS ORC;

INSERT INTO TABLE movie_genres
SELECT DISTINCT movie_id, title, genre
FROM movie_genres_ext
WHERE movie_id IS NOT NULL AND genre IS NOT NULL;

-- ==================== 4. 数据验证 ====================
SELECT '===== 数据加载验证 =====' AS info;
SELECT 'movies' AS tbl, COUNT(*) AS cnt FROM movies
UNION ALL
SELECT 'ratings', COUNT(*) FROM ratings
UNION ALL
SELECT 'users', COUNT(*) FROM users
UNION ALL
SELECT 'movie_genres', COUNT(*) FROM movie_genres;
