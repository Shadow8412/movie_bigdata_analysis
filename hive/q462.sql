USE movie_db;
SELECT * FROM tmp_ranked WHERE rnk <= 3 ORDER BY age_group, rnk;
