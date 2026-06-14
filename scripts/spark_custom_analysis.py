# -*- coding: utf-8 -*-
#=============================================================================
#  Spark 通用电影数据分析 — Custom Dataset
#=============================================================================
#  输入: ~/movie_bigdata_analysis/data/custom/*.csv
#  输出: MySQL movie_analysis (7张标准表)
#  特性: 自动检测列名/分隔符/文件类型，适配任意电影数据集
#=============================================================================

from pyspark.sql import SparkSession
from pyspark.sql.functions import (col, count, avg, round as sround, desc,
    countDistinct, when, split, explode, lit, sum as ssum)
import os, sys, glob

# ---- Init ----
ds_id = sys.argv[1] if len(sys.argv) > 1 else "0"
prefix = "" if ds_id == "0" else ("ds" + ds_id + "_")
print("Dataset ID: " + ds_id + " | Table prefix: " + (prefix or "(default)"))

spark = SparkSession.builder.appName("MovieCustom").getOrCreate()
spark.sparkContext.setLogLevel("WARN")

DATA_DIR = os.path.expanduser("~/movie_bigdata_analysis/data/custom/ds" + ds_id)

def ps(title): print("\n" + "="*60 + "\n  " + title + "\n" + "="*60)

def to_mysql(df, table, mode="overwrite"):
    full_table = prefix + table
    df.write.jdbc(
        url="jdbc:mysql://localhost:3306/movie_analysis?useSSL=false&characterEncoding=utf8",
        table=full_table, mode=mode,
        properties={"user":"movieapp","password":"movieapp123","driver":"com.mysql.jdbc.Driver"})
    print("  -> MySQL: " + full_table)

def detect_sep(f):
    with open(f,'r') as fh:
        l = fh.readline()
        if '::' in l: return '::'
        if '\t' in l: return '\t'
        return ','

def auto_map(df):
    """Rename columns to standard names"""
    alias_map = {}
    cols_low = {c.lower():c for c in df.columns}
    if 'movie_id' in cols_low: alias_map[cols_low['movie_id']] = 'movie_id'
    elif 'movieid' in cols_low: alias_map[cols_low['movieid']] = 'movie_id'
    elif 'movie' in cols_low: alias_map[cols_low['movie']] = 'movie_id'
    if 'user_id' in cols_low: alias_map[cols_low['user_id']] = 'user_id'
    elif 'userid' in cols_low: alias_map[cols_low['userid']] = 'user_id'
    elif 'user' in cols_low: alias_map[cols_low['user']] = 'user_id'
    if 'rating' in cols_low: alias_map[cols_low['rating']] = 'rating'
    elif 'score' in cols_low: alias_map[cols_low['score']] = 'rating'
    if 'title' in cols_low: alias_map[cols_low['title']] = 'title'
    if 'genres' in cols_low: alias_map[cols_low['genres']] = 'genres'
    elif 'genre' in cols_low: alias_map[cols_low['genre']] = 'genres'
    elif 'genres_raw' in cols_low: alias_map[cols_low['genres_raw']] = 'genres'
    if 'gender' in cols_low: alias_map[cols_low['gender']] = 'gender'
    if 'age' in cols_low: alias_map[cols_low['age']] = 'age'
    if 'time' in cols_low: alias_map[cols_low['time']] = 'time'
    elif 'timestamp' in cols_low: alias_map[cols_low['timestamp']] = 'time'
    sel = []
    for v in df.columns:
        if v in alias_map:
            sel.append(col(v).alias(alias_map[v]))
        else:
            sel.append(col(v))
    mapped = [v for v in df.columns if v in alias_map]
    if mapped: print("  Columns: " + ", ".join(mapped))
    return df.select(sel)

def load_all():
    files = glob.glob(DATA_DIR + "/*.csv") + glob.glob(DATA_DIR + "/*.dat")
    if not files:
        print("ERROR: No CSV in " + DATA_DIR)
        return None,None,None
    print("Files: " + str(len(files)))
    m, r, u = None, None, None
    for f in files:
        df = spark.read.option("header","true").option("inferSchema","true") \
            .option("delimiter", detect_sep(f)).csv("file://"+f)
        df = auto_map(df)
        cl = [c.lower() for c in df.columns]
        has_r = 'rating' in cl
        has_m = 'movie_id' in cl
        has_u = 'user_id' in cl
        if has_r and has_m and has_u:
            r = df; print("  " + os.path.basename(f) + " -> ratings")
        elif has_m and 'title' in cl and not has_r:
            m = df; print("  " + os.path.basename(f) + " -> movies")
        elif has_u and ('gender' in cl or 'age' in cl) and not has_r:
            u = df; print("  " + os.path.basename(f) + " -> users")
        elif has_r:
            r = df; print("  " + os.path.basename(f) + " -> ratings")
        else:
            print("  " + os.path.basename(f) + " -> skipped")
    return m, r, u

# ==================== MAIN ====================
ps("Spark Custom Dataset Analysis")
movies, ratings, users = load_all()

if ratings is None:
    print("ERROR: No ratings file found!"); spark.stop(); sys.exit(1)

ratings.cache()
if movies: movies.cache()
if users: users.cache()

# 1. Rating Distribution
ps("1. Rating Distribution")
rd = ratings.withColumn("score", col("rating").cast("int")) \
    .groupBy("score").agg(count("*").alias("count"))
tot = rd.agg(ssum("count")).collect()[0][0]
rd = rd.withColumn("percentage", sround(col("count")*100/tot, 2)).orderBy("score")
rd.show(); to_mysql(rd, "rating_distribution")

# 2. Top Movies
if movies:
    ps("2. Top 20 Movies")
    tm = ratings.join(movies, "movie_id").groupBy("title") \
        .agg(sround(avg("rating"),2).alias("avg_rating"), count("*").alias("rating_count")) \
        .filter(col("rating_count")>=3).orderBy(desc("avg_rating")).limit(20) \
        .select(col("title").alias("movie_name"), "avg_rating", "rating_count")
    tm.show(20,False); to_mysql(tm, "top_movies")
else:
    ps("2. Top Movies - SKIPPED (no movies.csv)")

# 3. Genre Stats
if movies and 'genres' in [c.lower() for c in movies.columns]:
    ps("3. Genre Statistics")
    gd = movies.select("movie_id", explode(split(col("genres"),"\\|")).alias("genre")).filter(col("genre")!="")
    gs = gd.join(ratings,"movie_id").groupBy("genre") \
        .agg(count("*").alias("rating_count"), sround(avg("rating"),2).alias("avg_rating")) \
        .join(gd.groupBy("genre").agg(countDistinct("movie_id").alias("movie_count")),"genre") \
        .orderBy(desc("movie_count")) \
        .select(col("genre").alias("genre_name"),"movie_count","avg_rating","rating_count")
    gs.show(20,False); to_mysql(gs, "genre_stats")
else:
    ps("3. Genre Stats - SKIPPED (no genres column)")

# 4. Active Users
ps("4. Active Users TOP20")
gcol = users["gender"].alias("gender") if users and "gender" in users.columns else lit("?").alias("gender")
acol = users["age"].cast("int").alias("age") if users and "age" in users.columns else lit(0).cast("int").alias("age")
ocol = users["occupation"].alias("occupation") if users and "occupation" in users.columns else lit("?").alias("occupation")
if users:
    au = ratings.join(users,"user_id").groupBy("user_id",gcol,acol,ocol) \
        .agg(count("*").alias("rating_count"), sround(avg("rating"),2).alias("avg_rating")) \
        .orderBy(desc("rating_count")).limit(20)
else:
    au = ratings.groupBy("user_id").agg(count("*").alias("rating_count"),
        sround(avg("rating"),2).alias("avg_rating")).orderBy(desc("rating_count")).limit(20)
    au = au.withColumn("gender",lit("?")).withColumn("age",lit(0)).withColumn("occupation",lit("?"))
au.show(20,False); to_mysql(au, "active_users")

# 5. Gender
if users and "gender" in users.columns:
    ps("5. Gender Comparison")
    tr = ratings.count()
    gc = ratings.join(users,"user_id").groupBy("gender") \
        .agg(count("*").alias("rating_count"), sround(avg("rating"),3).alias("avg_rating")) \
        .join(users.groupBy("gender").agg(countDistinct("user_id").alias("user_count")),"gender") \
        .withColumn("high_rate_pct", sround(col("rating_count")/tr*100,2))
    gc.show(); to_mysql(gc, "gender_comparison")
else:
    ps("5. Gender - SKIPPED")

# 6. Age Group
if users and "age" in users.columns:
    ps("6. Age Group")
    age_label = when(col("age")<=18,"Under18").when(col("age")<=25,"19-25") \
        .when(col("age")<=35,"26-35").when(col("age")<=45,"36-45") \
        .when(col("age")<=55,"46-55").otherwise("56+")
    wa = ratings.join(users.select("user_id","age"),"user_id").withColumn("age_group",age_label)
    ag = wa.groupBy("age_group") \
        .agg(count("*").alias("rating_count"), sround(avg("rating"),3).alias("avg_rating")) \
        .join(users.withColumn("age_group",age_label).groupBy("age_group")
            .agg(countDistinct("user_id").alias("user_count")),"age_group")
    ag.show(); to_mysql(ag, "age_group_stats")
else:
    ps("6. Age Group - SKIPPED")

# 7. Occupation
if users and "occupation" in users.columns:
    ps("7. Occupation Analysis")
    oc = ratings.join(users,"user_id").groupBy("occupation") \
        .agg(count("*").alias("rating_count"), sround(avg("rating"),3).alias("avg_rating")) \
        .join(users.groupBy("occupation").agg(countDistinct("user_id").alias("user_count")),"occupation") \
        .withColumn("rating_per_user", sround(col("rating_count")/col("user_count"),1)) \
        .orderBy(desc("rating_count")).limit(20)
    oc.show(20,False); to_mysql(oc, "occupation_stats")
else:
    ps("7. Occupation - SKIPPED")

# Summary
ps("Dashboard Summary")
tmv = movies.select("movie_id").distinct().count() if movies else 0
tr = ratings.count()
tu = ratings.select("user_id").distinct().count()
av = ratings.agg(sround(avg("rating"),3)).collect()[0][0]
summary = spark.createDataFrame([(tmv,tr,tu,av)],["total_movies","total_ratings","total_users","avg_rating"])
summary.show(); to_mysql(summary, "dashboard_summary")

print("\n" + "="*60 + "\n  Spark Custom Analysis Complete!\n" + "="*60)

# ---- Update datasets table ----
import subprocess
sql = "UPDATE datasets SET movie_count={0}, rating_count={1}, user_count={2} WHERE id={3}".format(tmv, tr, tu, ds_id)
try:
    subprocess.call([
        "mysql", "-u", "movieapp", "-pmovieapp123", "movie_analysis",
        "-e", sql
    ])
    print("  -> datasets table updated (id=" + ds_id + ")")
except Exception as ex:
    print("WARN: failed to update datasets: " + str(ex))

spark.stop()
