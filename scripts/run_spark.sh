#!/bin/bash
#=============================================================================
# Spark 电影评分大数据分析 - 一键执行脚本
# 使用 Spark DataFrame API 替代 Hive MapReduce
# 从 HDFS 读取 CSV → Spark 聚合分析 → 写入 MySQL
#=============================================================================
set -e

SPARK_HOME=${SPARK_HOME:-/usr/local/spark}
JDBC_JAR=/usr/local/spark/jars/mysql-connector-java-5.1.40/mysql-connector-java-5.1.40-bin.jar
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "  Spark 电影评分大数据分析"
echo "============================================"

# Check if Spark exists
if [ ! -f "$SPARK_HOME/bin/spark-submit" ]; then
    echo "[ERROR] Spark not found at $SPARK_HOME"
    exit 1
fi

echo "[INFO] Spark Home: $SPARK_HOME"
echo "[INFO] Spark Version: $($SPARK_HOME/bin/spark-submit --version 2>&1 | grep version | head -1)"

# Run Spark analysis
echo ""
echo "[INFO] Running Spark analysis..."
$SPARK_HOME/bin/spark-submit \
    --master local[4] \
    --jars "$JDBC_JAR" \
    "$SCRIPT_DIR/spark_analysis.py"

echo ""
echo "============================================"
echo "  Spark analysis complete!"
echo "  Results in MySQL: movie_analysis database"
echo "  Start web: cd webapp && mvn tomcat7:run"
echo "============================================"
