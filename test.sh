#!/bin/bash
#=============================================================================
# 一键测试脚本
# 用法: bash test.sh [选项]
#   bash test.sh           → 全流程测试
#   bash test.sh --preprocess  → 只测预处理
#   bash test.sh --hive        → 只测Hive查询(需要Docker已启动)
#   bash test.sh --web         → 启动Web可视化
#   bash test.sh --clean       → 清理Docker环境
#=============================================================================
set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 自动检测 docker compose 命令（V2: docker compose, V1: docker-compose）
if docker compose version &>/dev/null; then
    DCOMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
    DCOMPOSE="docker-compose"
else
    DCOMPOSE=""
fi

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ==================== 预处理测试 ====================
test_preprocess() {
    info "=== 测试: 数据预处理 ==="
    cd "$PROJECT_DIR"

    # 下载数据（如果还没下载）
    if [ ! -f "data/raw/ml-1m/ratings.dat" ]; then
        info "下载 MovieLens 1M 数据集..."
        mkdir -p data/raw
        wget -q --show-progress https://files.grouplens.org/datasets/movielens/ml-1m.zip \
            -O data/raw/ml-1m.zip
        unzip -o data/raw/ml-1m.zip -d data/raw/
    fi

    # 运行预处理
    info "运行预处理脚本..."
    python3 scripts/preprocess.py

    echo ""
    info "预处理完成! 输出文件:"
    ls -lh data/processed/
}

# ==================== Docker环境测试 ====================
test_docker_up() {
    info "=== 测试: 启动Docker大数据环境 ==="
    cd "$PROJECT_DIR"

    if ! command -v docker &>/dev/null; then
        err "请先安装 Docker: sudo apt install docker.io docker-compose-v2"
        exit 1
    fi
    if [ -z "$DCOMPOSE" ]; then
        err "未找到 docker compose 或 docker-compose 命令"
        exit 1
    fi

    # 检查镜像是否已本地存在
    HADOOP_OK=$(docker images -q bde2020/hadoop-namenode:2.0.0-hadoop2.7.4-java8 2>/dev/null)
    HIVE_OK=$(docker images -q bde2020/hive:2.3.2-postgresql-metastore 2>/dev/null)
    MYSQL_OK=$(docker images -q mysql:5.7 2>/dev/null)

    if [ -n "$HADOOP_OK" ] && [ -n "$HIVE_OK" ] && [ -n "$MYSQL_OK" ]; then
        info "镜像已本地存在，跳过拉取"
    else
        # 配置多个国内镜像源 + 增加超时时间
        info "配置 Docker 国内镜像源..."
        sudo mkdir -p /etc/docker
        sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
    "registry-mirrors": [
        "https://docker.m.daocloud.io",
        "https://dockerproxy.com",
        "https://hub.rat.dev",
        "https://docker.1ms.run",
        "https://docker.hpcloud.cloud"
    ],
    "max-concurrent-downloads": 3,
    "max-concurrent-uploads": 2
}
EOF
        sudo systemctl restart docker
        sleep 3
        info "  镜像源已配置(5个国内镜像)"

        # 检查是否有代理可用
        PROXY_IP=$(ip route | grep default | awk '{print $3}')
        HAS_PROXY=""
        if curl -s --connect-timeout 3 "http://${PROXY_IP}:7890" &>/dev/null; then
            HAS_PROXY="http://${PROXY_IP}:7890"
            info "  检测到代理: $HAS_PROXY"
        elif curl -s --connect-timeout 3 "http://${PROXY_IP}:10809" &>/dev/null; then
            HAS_PROXY="http://${PROXY_IP}:10809"
            info "  检测到代理: $HAS_PROXY"
        fi

        pull_with_retry() {
            local img=$1
            local max_retry=3
            for i in $(seq 1 $max_retry); do
                info "  拉取: $img (第${i}次)"
                if [ -n "$HAS_PROXY" ]; then
                    if HTTP_PROXY="$HAS_PROXY" HTTPS_PROXY="$HAS_PROXY" \
                       docker pull "$img" 2>&1 | tail -3; then
                        return 0
                    fi
                else
                    if docker pull "$img" 2>&1 | tail -3; then
                        return 0
                    fi
                fi
                if [ $i -lt $max_retry ]; then
                    warn "    失败，等待 10 秒后重试..."
                    sleep 10
                fi
            done
            return 1
        }

        info "拉取镜像..."
        FAILED=""
        for img in "mysql:5.7" \
                   "postgres:9.6" \
                   "bde2020/hadoop-namenode:2.0.0-hadoop2.7.4-java8" \
                   "bde2020/hadoop-datanode:2.0.0-hadoop2.7.4-java8" \
                   "bde2020/hive:2.3.2-postgresql-metastore"; do
            if docker images -q "$img" 2>/dev/null | grep -q .; then
                info "  已存在: $img"
            elif ! pull_with_retry "$img"; then
                warn "  拉取失败: $img"
                FAILED="$FAILED $img"
            fi
        done

        if [ -n "$FAILED" ]; then
            err "以下镜像拉取失败: $FAILED"
            err ""
            err "镜像拉取失败，请尝试以下任一方案："
            err ""
            err "  方案1: 检查主机是否开了代理(如Clash/V2Ray)，"
            err "         确保 '允许局域网连接' 已开启"
            err "  方案2: 在 Windows 上安装 Docker Desktop，"
            err "         运行 export_images.bat 导出镜像"
            err "  方案3: 请同学帮忙导出镜像文件传给你"
            err ""
            exit 1
        fi
    fi

    info "启动容器..."
    $DCOMPOSE up -d

    info "等待服务就绪..."
    sleep 15

    # 检查各服务
    echo ""
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "namenode|datanode|hive|movie-mysql"
    echo ""

    # 测试HDFS
    info "测试 HDFS 连接..."
    docker exec namenode hdfs dfs -ls / 2>/dev/null && info "  HDFS OK" || warn "  HDFS 还在启动中..."

    # 测试MySQL
    info "测试 MySQL 连接..."
    docker exec movie-mysql mysql -uroot -proot -e "SHOW DATABASES;" 2>/dev/null && info "  MySQL OK" || warn "  MySQL 还在启动中..."
}

# ==================== Hive测试 ====================
test_hive() {
    info "=== 测试: Hive分析查询 ==="
    cd "$PROJECT_DIR"

    # 确保预处理已完成
    if [ ! -f "data/processed/movies.csv" ]; then
        warn "预处理数据不存在，先执行预处理..."
        test_preprocess
    fi

    # 上传数据到HDFS
    info "上传数据到HDFS..."
    docker exec namenode hdfs dfs -mkdir -p /user/hive/warehouse/movie_db.db/raw_movies
    docker exec namenode hdfs dfs -mkdir -p /user/hive/warehouse/movie_db.db/raw_ratings
    docker exec namenode hdfs dfs -mkdir -p /user/hive/warehouse/movie_db.db/raw_users
    docker exec namenode hdfs dfs -mkdir -p /user/hive/warehouse/movie_db.db/raw_genres

    docker cp data/processed/movies.csv       namenode:/data/processed/
    docker cp data/processed/ratings.csv      namenode:/data/processed/
    docker cp data/processed/users.csv        namenode:/data/processed/
    docker cp data/processed/movie_genres.csv namenode:/data/processed/

    docker exec namenode hdfs dfs -put -f /data/processed/movies.csv  /user/hive/warehouse/movie_db.db/raw_movies/
    docker exec namenode hdfs dfs -put -f /data/processed/ratings.csv /user/hive/warehouse/movie_db.db/raw_ratings/
    docker exec namenode hdfs dfs -put -f /data/processed/users.csv   /user/hive/warehouse/movie_db.db/raw_users/
    docker exec namenode hdfs dfs -put -f /data/processed/movie_genres.csv /user/hive/warehouse/movie_db.db/raw_genres/
    info "  HDFS上传完成"

    # 复制脚本到Hive容器
    docker cp hive/01_create_tables.sql     hive-server:/tmp/
    docker cp hive/02_analysis_queries.sql  hive-server:/tmp/

    # 执行DDL建表
    info "执行 Hive DDL 建表..."
    docker exec hive-server /opt/hive/bin/hive -f /tmp/01_create_tables.sql 2>&1 | tail -15

    # 执行分析查询
    info "执行 Hive 分析查询..."
    docker exec hive-server /opt/hive/bin/hive -f /tmp/02_analysis_queries.sql 2>&1 | tee output/analysis_result.txt

    echo ""
    info "Hive 测试完成! 结果已保存到 output/analysis_result.txt"
}

# ==================== MySQL + Sqoop测试 ====================
test_mysql_export() {
    info "=== 测试: MySQL导出 ==="
    cd "$PROJECT_DIR"

    # 等待MySQL就绪
    info "等待MySQL就绪..."
    for i in {1..30}; do
        if docker exec movie-mysql mysql -uroot -proot -e "SELECT 1" 2>/dev/null; then
            break
        fi
        sleep 2
    done

    # 检查表结构
    info "MySQL 表结构:"
    docker exec movie-mysql mysql -uroot -proot movie_analysis -e "SHOW TABLES;"

    echo ""
    info "MySQL 测试完成! 数据库 movie_analysis 就绪"
    info "Sqoop 导出需在 Hive 中执行分析查询后，手动运行: bash output/sqoop_export.sh"
}

# ==================== Web可视化测试 ====================
test_web() {
    info "=== 测试: Web可视化启动 ==="
    cd "$PROJECT_DIR/webapp"

    # 确保MySQL有数据
    info "检查MySQL连接..."
    if ! docker exec movie-mysql mysql -uroot -proot movie_analysis -e "SHOW TABLES;" 2>/dev/null; then
        err "MySQL未就绪, 请先执行: bash test.sh --docker"
        exit 1
    fi

    # 方式1: Maven Tomcat插件
    if command -v mvn &>/dev/null; then
        info "使用 Maven Tomcat7 插件启动 (Ctrl+C 停止)..."
        info "浏览器访问: http://localhost:8080/movie-analysis"
        mvn clean compile tomcat7:run
    else
        # 方式2: 如果没有Maven，直接用Tomcat
        warn "未安装Maven，请手动部署:"
        echo "  1. 安装Tomcat: sudo apt install tomcat9"
        echo "  2. 复制webapp到 /var/lib/tomcat9/webapps/movie-analysis/"
        echo "  3. 启动: sudo systemctl start tomcat9"
        echo "  4. 访问: http://localhost:8080/movie-analysis"
    fi
}

# ==================== 清理 ====================
test_clean() {
    info "=== 清理Docker环境 ==="
    cd "$PROJECT_DIR"
    $DCOMPOSE down -v
    rm -rf data/raw data/processed/*
    info "清理完成"
}

# ==================== 主流程 ====================
case "${1:-}" in
    --preprocess)   test_preprocess ;;
    --docker)       test_docker_up ;;
    --hive)         test_hive ;;
    --mysql)        test_mysql_export ;;
    --web)          test_web ;;
    --clean)        test_clean ;;
    "")
        # 全流程
        info "============================================"
        info "  电影评分大数据分析系统 — 全流程测试"
        info "============================================"
        echo ""

        test_preprocess
        echo ""
        test_docker_up
        echo ""
        test_hive
        echo ""
        test_mysql_export
        echo ""

        info "============================================"
        info "  测试全部通过！"
        info "============================================"
        info "  启动Web可视化: bash test.sh --web"
        info "  浏览器访问:    http://localhost:8080/movie-analysis"
        info "  HDFS面板:      http://localhost:50070"
        ;;
    *)
        echo "用法: bash test.sh [选项]"
        echo ""
        echo "  (无参数)            全流程测试"
        echo "  --preprocess        仅预处理"
        echo "  --docker            仅启动Docker环境"
        echo "  --hive              仅Hive分析"
        echo "  --mysql             仅测MySQL"
        echo "  --web               启动Web可视化"
        echo "  --clean             清理环境"
        ;;
esac
