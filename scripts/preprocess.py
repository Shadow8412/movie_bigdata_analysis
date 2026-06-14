#!/usr/bin/env python3
#=============================================================================
# 数据预处理脚本
# 负责成员: B (数据采集与预处理)
# 功能: 格式转换、删除表头、字段清洗、Genres拆分
#=============================================================================
import os, sys, csv

RAW_DIR  = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "raw", "ml-1m")
OUT_DIR  = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "processed")
os.makedirs(OUT_DIR, exist_ok=True)

# ==================== 读取原始数据 ====================
def load_raw(filename):
    """读取 :: 分隔的原始文件，跳过表头(若存在)"""
    path = os.path.join(RAW_DIR, filename)
    if not os.path.exists(path):
        print(f"[错误] 文件不存在: {path}")
        sys.exit(1)
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
    print(f"  读取 {filename}: {len(lines)} 行")
    return lines

# ==================== 1. 处理 movies.dat ====================
print("=" * 60)
print("[预处理] 1. 处理 movies.dat")
movies_raw = load_raw("movies.dat")
movies_out = []
genres_out = []   # 拆分后的类别表

for line in movies_raw:
    line = line.strip()
    if not line:
        continue
    # 删除可能的首行表头
    if line.startswith("MovieID::") or line.startswith("movieId"):
        continue
    parts = line.split("::")
    if len(parts) < 3:
        continue
    mid, title, genres_str = parts[0], parts[1], parts[2]
    # 清洗: 去除年份括号(如 "Toy Story (1995)" → "Toy Story")
    import re
    title_clean = re.sub(r'\s*\(\d{4}\)\s*$', '', title).strip()
    # 原始标题保留在另一字段
    movies_out.append([mid, title_clean, title.strip(), genres_str])

    # 拆分Genres (Action|Comedy → 多行)
    for g in genres_str.split("|"):
        g = g.strip()
        if g:
            genres_out.append([mid, title_clean, g])

# 写入处理后的文件
with open(os.path.join(OUT_DIR, "movies.csv"), "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f, lineterminator="\n")
    w.writerow(["movie_id", "title", "title_full", "genres_raw"])
    w.writerows(movies_out)

with open(os.path.join(OUT_DIR, "movie_genres.csv"), "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f, lineterminator="\n")
    w.writerow(["movie_id", "title", "genre"])
    w.writerows(genres_out)

print(f"  输出: movies.csv ({len(movies_out)} 行)")
print(f"  输出: movie_genres.csv ({len(genres_out)} 行)")

# ==================== 2. 处理 ratings.dat ====================
print("[预处理] 2. 处理 ratings.dat")
ratings_raw = load_raw("ratings.dat")
ratings_out = []

for line in ratings_raw:
    line = line.strip()
    if not line:
        continue
    if line.startswith("UserID::") or line.startswith("userId"):
        continue
    parts = line.split("::")
    if len(parts) < 4:
        continue
    uid, mid, rating, ts = parts[0], parts[1], parts[2], parts[3]
    # 类型校验
    try:
        int(uid); int(mid); float(rating); int(ts)
    except ValueError:
        continue
    if not (1 <= float(rating) <= 5):
        continue
    ratings_out.append([uid, mid, rating, ts])

with open(os.path.join(OUT_DIR, "ratings.csv"), "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f, lineterminator="\n")
    w.writerow(["user_id", "movie_id", "rating", "timestamp"])
    w.writerows(ratings_out)

print(f"  输出: ratings.csv ({len(ratings_out)} 行)")

# ==================== 3. 处理 users.dat ====================
print("[预处理] 3. 处理 users.dat")
users_raw = load_raw("users.dat")
users_out = []

# 年龄分组映射
def age_group(age):
    a = int(age)
    if a <= 18:    return "Under18"
    elif a <= 25:  return "19-25"
    elif a <= 35:  return "26-35"
    elif a <= 45:  return "36-45"
    elif a <= 55:  return "46-55"
    else:          return "56+"

# 职业映射 (MovieLens标准)
occupation_map = {
    0:"other", 1:"academic/educator", 2:"artist", 3:"clerical/admin",
    4:"college/grad student", 5:"customer service", 6:"doctor/health care",
    7:"executive/managerial", 8:"farmer", 9:"homemaker",
    10:"K-12 student", 11:"lawyer", 12:"programmer", 13:"retired",
    14:"sales/marketing", 15:"scientist", 16:"self-employed",
    17:"technician/engineer", 18:"tradesman/craftsman",
    19:"unemployed", 20:"writer"
}

for line in users_raw:
    line = line.strip()
    if not line:
        continue
    if line.startswith("UserID::") or line.startswith("userId"):
        continue
    parts = line.split("::")
    if len(parts) < 5:
        continue
    uid, gender, age_str, occ_str, zipcode = parts[0], parts[1], parts[2], parts[3], parts[4]
    # 性别: M/F → Male/Female
    gender_full = "Male" if gender.upper() == "M" else "Female"
    age = age_str.strip()
    occ = occ_str.strip()
    users_out.append([
        uid, gender_full, age, age_group(age),
        occ, occupation_map.get(int(occ) if occ.isdigit() else -1, "unknown"),
        zipcode.strip()
    ])

with open(os.path.join(OUT_DIR, "users.csv"), "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f, lineterminator="\n")
    w.writerow(["user_id", "gender", "age", "age_group", "occupation_id", "occupation", "zipcode"])
    w.writerows(users_out)

print(f"  输出: users.csv ({len(users_out)} 行)")

# ==================== 4. 统计报告 ====================
print("\n" + "=" * 60)
print("[预处理] 完成! 数据统计报告:")
print(f"  电影数量:      {len(movies_out)}")
print(f"  类别记录:      {len(genres_out)} (拆分后)")
print(f"  评分记录:      {len(ratings_out)}")
print(f"  用户数量:      {len(users_out)}")
print(f"  评分分布:      1-5分 (需Hive分析)")
print(f"  性别分布:      {sum(1 for u in users_out if u[1]=='Male')} 男 / {sum(1 for u in users_out if u[1]=='Female')} 女")

# 输出文件清单
print(f"\n预处理输出目录: {OUT_DIR}")
for f in sorted(os.listdir(OUT_DIR)):
    fpath = os.path.join(OUT_DIR, f)
    print(f"  {f}  →  {os.path.getsize(fpath):>8,} bytes  |  {sum(1 for _ in open(fpath)):>6,} 行")
