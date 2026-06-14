#!/bin/bash
#=============================================================================
# 一键执行脚本
# 按顺序执行: 环境检查 → 预处理 → HDFS上传 → Hive建表 → 分析查询 → Sqoop导出
# 负责成员: C (数据存储，整合全流程)
#=============================================================================
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${PROJECT_DIR}/data/processed"
HIVE_DIR="${PROJECT_DIR}/hive"
OUTPUT_DIR="${PROJECT_DIR}/output"

echo "============================================"
echo "  电影评分大数据分析 — 一键执行流程"
echo "============================================"

# Step 1: 检查环境
echo ""
echo "[Step 1/6] 检查环境..."
bash "${PROJECT_DIR}/scripts/check_env.sh"

# Step 2: 数据预处理（如未运行）
echo ""
echo "[Step 2/6] 数据预处理..."
if [ ! -f "${DATA_DIR}/movies.csv" ]; then
    python3 "${PROJECT_DIR}/scripts/preprocess.py"
else
    echo "  预处理已完成，跳过"
fi

# Step 3: 上传到HDFS
echo ""
echo "[Step 3/6] 上传数据到HDFS..."
hdfs dfs -mkdir -p /user/hive/warehouse/movie_db.db/raw_movies
hdfs dfs -mkdir -p /user/hive/warehouse/movie_db.db/raw_ratings
hdfs dfs -mkdir -p /user/hive/warehouse/movie_db.db/raw_users
hdfs dfs -mkdir -p /user/hive/warehouse/movie_db.db/raw_genres

hdfs dfs -put -f "${DATA_DIR}/movies.csv"  /user/hive/warehouse/movie_db.db/raw_movies/
hdfs dfs -put -f "${DATA_DIR}/ratings.csv" /user/hive/warehouse/movie_db.db/raw_ratings/
hdfs dfs -put -f "${DATA_DIR}/users.csv"   /user/hive/warehouse/movie_db.db/raw_users/
hdfs dfs -put -f "${DATA_DIR}/movie_genres.csv" /user/hive/warehouse/movie_db.db/raw_genres/

echo "  HDFS上传完成"
hdfs dfs -ls /user/hive/warehouse/movie_db.db/

# Step 4: Hive建表并加载
echo ""
echo "[Step 4/6] Hive建表与数据加载..."
hive -f "${HIVE_DIR}/01_create_tables.sql"

# Step 5: 执行分析查询
echo ""
echo "[Step 5/6] 执行分析查询..."
hive -f "${HIVE_DIR}/02_analysis_queries.sql" 2>&1 | tee "${PROJECT_DIR}/output/analysis_result.txt"

# Step 6: Sqoop导出到MySQL
echo ""
echo "[Step 6/6] Sqoop导出到MySQL..."
echo "  请确保MySQL已启动且已执行 mysql_schema.sql"
read -p "  是否继续执行Sqoop导出? (y/n): " confirm
if [ "$confirm" = "y" ]; then
    bash "${OUTPUT_DIR}/sqoop_export.sh"
else
    echo "  跳过Sqoop导出，可稍后手动执行"
fi

echo ""
echo "============================================"
echo "  全流程执行完成!"
echo "============================================"
echo "  分析结果: ${PROJECT_DIR}/output/analysis_result.txt"
echo "  MySQL数据: movie_analysis 数据库"
echo "  启动Web可视化: cd webapp && mvn tomcat7:run"
