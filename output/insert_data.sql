-- Sample data from Hive analysis for demo
USE movie_analysis;

-- 1. Rating distribution
INSERT INTO rating_distribution VALUES
(1, 56174, 5.62),
(2, 107557, 10.75),
(3, 261197, 26.12),
(4, 348971, 34.89),
(5, 226310, 22.63);

-- 4. Gender comparison
INSERT INTO gender_comparison VALUES
('Female', 1709, 246440, 3.620, 59.07),
('Male', 4331, 753769, 3.569, 57.01);

-- 5. Age group stats
INSERT INTO age_group_stats VALUES
('Under18', 1325, 210747, 3.513),
('19-25', 2096, 395556, 3.545),
('26-35', 1193, 199003, 3.618),
('36-45', 550, 83633, 3.638),
('46-55', 496, 72490, 3.715),
('56+', 380, 38780, 3.767);

-- 6. Occupation stats
INSERT INTO occupation_stats (occupation, user_count, rating_count, avg_rating, rating_per_user) VALUES
('college/grad student', 759, 131032, 3.537, 172.6),
('other', 711, 130499, 3.538, 183.5),
('executive/managerial', 679, 105425, 3.600, 155.3),
('academic/educator', 528, 85351, 3.577, 161.6),
('technician/engineer', 502, 72816, 3.614, 145.1),
('writer', 281, 60397, 3.497, 214.9),
('programmer', 388, 57214, 3.654, 147.5),
('artist', 267, 50068, 3.573, 187.5),
('sales/marketing', 302, 49109, 3.618, 162.6),
('self-employed', 241, 46021, 3.597, 191.0),
('doctor/health care', 236, 37205, 3.662, 157.6),
('clerical/admin', 173, 31623, 3.657, 182.8),
('K-12 student', 195, 23290, 3.533, 119.4),
('scientist', 144, 22951, 3.690, 159.4),
('customer service', 112, 21850, 3.538, 195.1),
('lawyer', 129, 20563, 3.617, 159.4),
('unemployed', 72, 14904, 3.414, 207.0),
('retired', 142, 13754, 3.782, 96.9),
('tradesman/craftsman', 70, 12086, 3.530, 172.7),
('homemaker', 92, 11345, 3.657, 123.3);

-- 7. Active users TOP20
INSERT INTO active_users (user_id, gender, age, occupation, rating_count, avg_rating) VALUES
(4169, 'Male', 50, 'other', 2314, 3.55),
(1680, 'Male', 25, 'writer', 1850, 3.56),
(4277, 'Male', 35, 'self-employed', 1743, 4.13),
(1941, 'Male', 35, 'technician/engineer', 1595, 3.05),
(1181, 'Male', 35, 'executive/managerial', 1521, 2.82),
(889, 'Male', 45, 'writer', 1518, 2.84),
(3618, 'Male', 56, 'technician/engineer', 1344, 3.01),
(2063, 'Male', 25, 'college/grad student', 1323, 2.95),
(1150, 'Female', 25, 'writer', 1302, 2.59),
(1015, 'Male', 35, 'clerical/admin', 1286, 3.73),
(5795, 'Male', 25, 'academic/educator', 1277, 3.06),
(4344, 'Male', 25, 'academic/educator', 1271, 3.33),
(1980, 'Male', 35, 'executive/managerial', 1260, 3.48),
(2909, 'Male', 25, 'executive/managerial', 1258, 3.82),
(1449, 'Male', 35, 'writer', 1243, 2.81),
(4510, 'Male', 45, 'executive/managerial', 1240, 2.84),
(424, 'Male', 25, 'technician/engineer', 1226, 3.74),
(4227, 'Male', 25, 'unemployed', 1222, 2.70),
(5831, 'Male', 25, 'academic/educator', 1220, 3.68),
(3391, 'Male', 18, 'college/grad student', 1216, 3.72);
