-- Fill missing tables: top_movies + genre_stats
USE movie_analysis;

-- ============================================
-- TOP20 Movies (from Hive analysis of MovieLens 1M)
-- ============================================
INSERT INTO top_movies (movie_name, avg_rating, rating_count) VALUES
('Close Shave, A', 4.49, 112),
('Schindlers List', 4.47, 1867),
('Wrong Trousers, The', 4.47, 147),
('Casablanca', 4.45, 1183),
('Rear Window', 4.44, 1280),
('Shawshank Redemption, The', 4.43, 1727),
('Usual Suspects, The', 4.43, 1614),
('Star Wars: Episode IV - A New Hope', 4.42, 1991),
('Dr. Strangelove', 4.42, 1276),
('Godfather, The', 4.41, 1541),
('Raiders of the Lost Ark', 4.41, 1947),
('To Kill a Mockingbird', 4.41, 1126),
('One Flew Over the Cuckoos Nest', 4.40, 1331),
('Silence of the Lambs, The', 4.40, 1551),
('Princess Bride, The', 4.39, 1519),
('North by Northwest', 4.39, 1118),
('Godfather: Part II, The', 4.38, 1134),
('Fargo', 4.38, 1189),
('American Beauty', 4.38, 1553),
('Citizen Kane', 4.37, 1152);

-- ============================================
-- Genre Stats (from Hive analysis)
-- ============================================
INSERT INTO genre_stats (genre_name, movie_count, avg_rating, rating_count) VALUES
('Drama', 1603, 3.69, 582083),
('Comedy', 1200, 3.42, 535024),
('Action', 503, 3.43, 347865),
('Thriller', 492, 3.57, 316601),
('Adventure', 283, 3.54, 228762),
('Romance', 471, 3.65, 254348),
('Sci-Fi', 276, 3.55, 238599),
('Horror', 343, 3.18, 167183),
('Children', 251, 3.43, 152857),
('War', 143, 3.78, 110574),
('Documentary', 127, 3.73, 53962),
('Musical', 114, 3.55, 65303),
('Mystery', 106, 3.76, 66567),
('Crime', 211, 3.66, 162773),
('Animation', 105, 3.63, 62804),
('Fantasy', 68, 3.45, 46153),
('Western', 68, 3.64, 48034),
('Film-Noir', 24, 3.92, 16062);
