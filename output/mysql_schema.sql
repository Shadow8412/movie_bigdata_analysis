-- =============================================================================
-- MySQL 结果表结构
-- 负责成员: C (存储) + D (分析结果格式定义)
-- 用于存储 Hive 分析结果，供 JSP Web 可视化读取
-- =============================================================================

CREATE DATABASE IF NOT EXISTS movie_analysis
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE movie_analysis;

-- 1. 评分分布表
DROP TABLE IF EXISTS rating_distribution;
CREATE TABLE rating_distribution (
    score      INT PRIMARY KEY,
    count      BIGINT,
    percentage DECIMAL(5,2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. 热门电影TOP20表
DROP TABLE IF EXISTS top_movies;
CREATE TABLE top_movies (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    movie_name   VARCHAR(200),
    avg_rating   DECIMAL(4,2),
    rating_count INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. 电影类别统计表
DROP TABLE IF EXISTS genre_stats;
CREATE TABLE genre_stats (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    genre_name   VARCHAR(50),
    movie_count  INT,
    avg_rating   DECIMAL(4,2),
    rating_count INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. 活跃用户表
DROP TABLE IF EXISTS active_users;
CREATE TABLE active_users (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT,
    gender        VARCHAR(10),
    age           INT,
    occupation    VARCHAR(50),
    rating_count  INT,
    avg_rating    DECIMAL(4,2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. 性别对比表
DROP TABLE IF EXISTS gender_comparison;
CREATE TABLE gender_comparison (
    gender        VARCHAR(10) PRIMARY KEY,
    user_count    INT,
    rating_count  BIGINT,
    avg_rating    DECIMAL(5,3),
    high_rate_pct DECIMAL(5,2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. 年龄段分析表
DROP TABLE IF EXISTS age_group_stats;
CREATE TABLE age_group_stats (
    age_group    VARCHAR(20) PRIMARY KEY,
    user_count   INT,
    rating_count BIGINT,
    avg_rating   DECIMAL(5,3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. 职业分析表
DROP TABLE IF EXISTS occupation_stats;
CREATE TABLE occupation_stats (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    occupation      VARCHAR(50),
    user_count      INT,
    rating_count    BIGINT,
    avg_rating      DECIMAL(5,3),
    rating_per_user DECIMAL(5,1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ==================== Custom Upload Tables ====================
-- Used by UploadServlet for user-uploaded movie datasets

DROP TABLE IF EXISTS movies_custom;
CREATE TABLE movies_custom (
    movie_id INT,
    title VARCHAR(500),
    title_full VARCHAR(500),
    genres_raw VARCHAR(500)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS ratings_custom;
CREATE TABLE ratings_custom (
    user_id INT,
    movie_id INT,
    rating DOUBLE,
    ts BIGINT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS users_custom;
CREATE TABLE users_custom (
    user_id INT,
    gender VARCHAR(10),
    age INT,
    age_group VARCHAR(20),
    occupation_id INT,
    occupation VARCHAR(50),
    zipcode VARCHAR(20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
