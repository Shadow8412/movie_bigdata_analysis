USE movie_analysis;
CREATE TABLE IF NOT EXISTS datasets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    movie_count INT DEFAULT 0,
    rating_count BIGINT DEFAULT 0,
    user_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT IGNORE INTO datasets (id, name, movie_count, rating_count, user_count) VALUES (0, 'MovieLens 1M (default)', 3883, 1000209, 6040);
