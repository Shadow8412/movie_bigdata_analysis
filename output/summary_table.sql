USE movie_analysis;

-- 仪表板汇总统计表
DROP TABLE IF EXISTS dashboard_summary;
CREATE TABLE dashboard_summary (
    id INT AUTO_INCREMENT PRIMARY KEY,
    total_movies INT,
    total_ratings BIGINT,
    total_users INT,
    avg_rating DECIMAL(5,3)
);

INSERT INTO dashboard_summary VALUES (1, 3883, 1000209, 6040, 3.582);
