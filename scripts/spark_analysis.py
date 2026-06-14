# -*- coding: utf-8 -*-
#=============================================================================
# Spark 电影评分大数据分析 (PySpark)
# ============================================================================
# 功能: 替代 Hive MapReduce，使用 Spark DataFrame API 完成全部 7 类分析
# 流程: HDFS CSV → Spark DataFrame → groupBy/agg/join → MySQL (JDBC)
# 运行: /usr/local/spark/bin/spark-submit --jars mysql-connector.jar spark_analysis.py
# 环境: Spark 2.1.0 + Python 3.5 + Hadoop 2.7.1 + MySQL 5.7
# ============================================================================

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, avg, round as sround, sum as ssum, row_number, desc, lit
from pyspark.sql.window import Window

# ==================== SparkSession 初始化 ====================
# 创建本地模式的 SparkSession（单机多线程，充分利用多核 CPU）
spark = SparkSession.builder \
    .appName("MovieAnalysis") \
    .config("spark.sql.warehouse.dir", "/user/hive/warehouse") \
    .getOrCreate()
spark.sparkContext.setLogLevel("WARN")  # 只显示 WARN 以上日志，减少输出噪音

# HDFS 数据根路径（预处理后的 CSV 文件存放位置）
HDFS = "hdfs://localhost:9000/user/hive/warehouse/movie_db.db"

# ==================== 数据加载 (HDFS CSV → DataFrame) ====================
# Spark 直接从 HDFS 读取 CSV，无需 Hive 中转
# option("header","true") 让 Spark 自动解析 CSV 表头作为列名
# .cast() 进行类型转换，确保后续聚合计算正确

movies = spark.read.option("header", "true").csv(HDFS + "/raw_movies/*.csv") \
    .select(col("movie_id").cast("int"),       # 电影ID (整数)
            col("title"),                       # 电影名称 (去年份版)
            col("title_full"),                  # 完整标题 (含年份)
            col("genres_raw"))                  # 原始类别字符串 (如 Action|Comedy)

ratings = spark.read.option("header", "true").csv(HDFS + "/raw_ratings/*.csv") \
    .select(col("user_id").cast("int"),         # 用户ID
            col("movie_id").cast("int"),         # 电影ID
            col("rating").cast("double"),        # 评分 (1-5)
            col("timestamp").cast("bigint").alias("ts"))  # Unix时间戳

users = spark.read.option("header", "true").csv(HDFS + "/raw_users/*.csv") \
    .select(col("user_id").cast("int"),
            col("gender"),                      # 性别 (M/F)
            col("age").cast("int"),              # 年龄数值
            col("age_group"),                   # 年龄段标签 (Under18/19-25/...)
            col("occupation_id").cast("int"),    # 职业编码
            col("occupation"),                  # 职业名称
            col("zipcode"))                     # 邮编

genres = spark.read.option("header", "true").csv(HDFS + "/raw_genres/*.csv") \
    .select(col("movie_id").cast("int"),
            col("title"),
            col("genre"))                       # 拆分后的单一类别

# 缓存到内存: 4个 DataFrame 被多次使用，缓存避免重复读 HDFS
ratings.cache(); movies.cache(); users.cache(); genres.cache()

# ==================== 工具函数 ====================

def print_section(title):
    """打印分隔标题"""
    print("\n" + "="*60 + "\n  " + title + "\n" + "="*60)

def to_mysql(df, table, mode="append"):
    """
    将 DataFrame 写入 MySQL 对应表
    使用 append 模式（表结构需已由 mysql_schema.sql 创建）
    JDBC URL 中的参数: useSSL=false (内网免SSL), characterEncoding=utf8 (支持中文)
    """
    df.write.jdbc(
        url="jdbc:mysql://localhost:3306/movie_analysis?useSSL=false&characterEncoding=utf8",
        table=table, mode=mode,
        properties={"user": "movieapp", "password": "movieapp123", "driver": "com.mysql.jdbc.Driver"}
    )
    print("  -> Written to MySQL table: " + table)

# ======================================================================
#  分析 1: 评分整体分布
#  方法: 按评分数值分组 → 计每个分数的数量 → 计算百分比
#  对应 MySQL 表: rating_distribution (score, count, percentage)
# ======================================================================
print_section("1. Rating Distribution")
rating_dist = ratings.groupBy(sround(col("rating"), 0).cast("int").alias("score")) \
    .agg(count("*").alias("count"))
total = rating_dist.agg(ssum("count")).collect()[0][0]
rating_dist = rating_dist.withColumn("percentage", sround(col("count")*100/total, 2)) \
    .orderBy("score")
rating_dist.show()
to_mysql(rating_dist, "rating_distribution")

# ======================================================================
#  分析 2: 评分最高 TOP20 电影
#  方法: ratings JOIN movies → 按title分组 → 计算均分和人数 → 过滤>=50人 → 取前20
#  关键: filter(rating_count>=50) 避免小众高分片
#  列名映射: title → movie_name (对齐 MySQL 表结构)
#  对应 MySQL 表: top_movies (movie_name, avg_rating, rating_count)
# ======================================================================
print_section("2. Top 20 Movies by Average Rating")
top_movies = ratings.join(movies, "movie_id") \
    .groupBy("title") \
    .agg(sround(avg("rating"), 2).alias("avg_rating"), count("*").alias("rating_count")) \
    .filter(col("rating_count") >= 50) \
    .orderBy(desc("avg_rating")).limit(20) \
    .select(col("title").alias("movie_name"), "avg_rating", "rating_count")
top_movies.show(20, truncate=False)
to_mysql(top_movies, "top_movies")

# ======================================================================
#  分析 3: 电影类别统计
#  方法: 两次 groupBy —— ① genres+ratings 计算评分 ② genres 计算电影数 → JOIN
#  列名映射: genre → genre_name (对齐 MySQL 表结构)
#  对应 MySQL 表: genre_stats (genre_name, movie_count, avg_rating, rating_count)
# ======================================================================
print_section("3. Genre Statistics")
genre_stats = genres.join(ratings, "movie_id") \
    .groupBy("genre") \
    .agg(count("*").alias("rating_count"),
         sround(avg("rating"), 2).alias("avg_rating")) \
    .join(
        genres.groupBy("genre").agg(count("movie_id").alias("movie_count")),
        "genre"
    ).orderBy(desc("movie_count")) \
    .select(col("genre").alias("genre_name"), "movie_count", "avg_rating", "rating_count")
genre_stats.show(20, truncate=False)
to_mysql(genre_stats, "genre_stats")

# ======================================================================
#  分析 4: 最活跃用户 TOP20
#  方法: ratings JOIN users → groupBy 用户属性 → 按评分次数降序 → LIMIT 20
#  对应 MySQL 表: active_users (user_id, gender, age, occupation, rating_count, avg_rating)
# ======================================================================
print_section("4. Most Active Users TOP20")
active_users = ratings.join(users, "user_id") \
    .groupBy("user_id", "gender", "age", "occupation") \
    .agg(count("*").alias("rating_count"), sround(avg("rating"), 2).alias("avg_rating")) \
    .orderBy(desc("rating_count")).limit(20)
active_users.show(20, truncate=False)
to_mysql(active_users, "active_users")

# ======================================================================
#  分析 5: 男女用户评分对比
#  方法: 两次 groupBy(gender) —— ① 统计评分 ② 统计用户数 → JOIN → 计算好评率
#  high_rate_pct = 该性别评分数 / 总评分数 * 100
#  对应 MySQL 表: gender_comparison (gender, user_count, rating_count, avg_rating, high_rate_pct)
# ======================================================================
print_section("5. Gender Comparison")
gender_comp = ratings.join(users, "user_id") \
    .groupBy("gender") \
    .agg(count("*").alias("rating_count"),
         sround(avg("rating"), 3).alias("avg_rating")) \
    .join(
        users.groupBy("gender").agg(count("user_id").alias("user_count")),
        "gender"
    )
total_ratings = ratings.count()
gender_comp = gender_comp.withColumn("high_rate_pct",
    sround(col("rating_count") / lit(total_ratings) * 100, 2))
gender_comp.show()
to_mysql(gender_comp, "gender_comparison")

# ======================================================================
#  分析 6: 各年龄段用户评分行为
#  方法: 同上，按 age_group 分组统计评分数量、平均分、用户数
#  对应 MySQL 表: age_group_stats (age_group, user_count, rating_count, avg_rating)
# ======================================================================
print_section("6. Age Group Analysis")
age_stats = ratings.join(users, "user_id") \
    .groupBy("age_group") \
    .agg(count("*").alias("rating_count"),
         sround(avg("rating"), 3).alias("avg_rating")) \
    .join(
        users.groupBy("age_group").agg(count("user_id").alias("user_count")),
        "age_group"
    )
age_stats.show()
to_mysql(age_stats, "age_group_stats")

# ======================================================================
#  分析 7: 各职业用户评分习惯
#  方法: groupBy(occupation) 统计 → 计算人均评分 (rating_count/user_count) → 取前20
#  对应 MySQL 表: occupation_stats (occupation, user_count, rating_count, avg_rating, rating_per_user)
# ======================================================================
print_section("7. Occupation Analysis")
occ_stats = ratings.join(users, "user_id") \
    .groupBy("occupation") \
    .agg(count("*").alias("rating_count"),
         sround(avg("rating"), 3).alias("avg_rating")) \
    .join(
        users.groupBy("occupation").agg(count("user_id").alias("user_count")),
        "occupation"
    ) \
    .withColumn("rating_per_user", sround(col("rating_count")/col("user_count"), 1)) \
    .orderBy(desc("rating_count")).limit(20)
occ_stats.show(20, truncate=False)
to_mysql(occ_stats, "occupation_stats")

# ---- Summary ----
print_section("Dashboard Summary")
summary = spark.createDataFrame([(
    3883,                                    # total_movies
    ratings.count(),                         # total_ratings
    users.select("user_id").distinct().count(),  # total_users
    ratings.agg(sround(avg("rating"), 3)).collect()[0][0]  # avg_rating
)], ["total_movies", "total_ratings", "total_users", "avg_rating"])
summary.show()
to_mysql(summary, "dashboard_summary")

print("\n" + "="*60)
print("  Spark Analysis Complete! All 7 results written to MySQL.")
print("="*60)

spark.stop()
