#!/bin/bash
#=============================================================================
# 数据集下载脚本
# 负责成员: B (数据采集与预处理)
# 下载 MovieLens 1M 数据集
#=============================================================================
set -e

DATA_DIR="$(cd "$(dirname "$0")" && pwd)"
RAW_DIR="${DATA_DIR}/raw"
mkdir -p "${RAW_DIR}"

echo "[采集] 开始下载 MovieLens 1M 数据集..."

# 方法1: wget 直接下载
if command -v wget &>/dev/null; then
    wget -c https://files.grouplens.org/datasets/movielens/ml-1m.zip \
        -O "${RAW_DIR}/ml-1m.zip"
elif command -v curl &>/dev/null; then
    curl -L -C - https://files.grouplens.org/datasets/movielens/ml-1m.zip \
        -o "${RAW_DIR}/ml-1m.zip"
else
    echo "[错误] 需要安装 wget 或 curl"
    exit 1
fi

# 解压
echo "[采集] 解压数据集..."
cd "${RAW_DIR}"
unzip -o ml-1m.zip

# 验证文件
echo "[采集] 验证数据文件..."
for f in movies.dat ratings.dat users.dat; do
    if [ -f "${RAW_DIR}/ml-1m/${f}" ]; then
        wc -l "${RAW_DIR}/ml-1m/${f}"
    else
        echo "[错误] 文件缺失: ${f}"
        exit 1
    fi
done

echo "[采集] 下载完成!"
echo "  movies.dat  → $(wc -l < "${RAW_DIR}/ml-1m/movies.dat") 行"
echo "  ratings.dat → $(wc -l < "${RAW_DIR}/ml-1m/ratings.dat") 行"
echo "  users.dat   → $(wc -l < "${RAW_DIR}/ml-1m/users.dat") 行"
