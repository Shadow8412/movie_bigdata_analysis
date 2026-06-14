CREATE USER IF NOT EXISTS 'movieapp'@'%' IDENTIFIED BY 'movieapp123';
GRANT ALL PRIVILEGES ON movie_analysis.* TO 'movieapp'@'%';
FLUSH PRIVILEGES;
SELECT User, Host FROM mysql.user WHERE User='movieapp';
