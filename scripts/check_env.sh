#!/bin/bash
#=============================================================================
# 环境检查脚本
# 检查 Hadoop/Hive/MySQL/Sqoop 是否可用
#=============================================================================
echo "===== 大数据环境检查 ====="
echo ""

check_cmd() {
    if command -v "$1" &>/dev/null; then
        echo "  [OK] $1  →  $(command -v $1)"
        return 0
    else
        echo "  [MISS] $1"
        return 1
    fi
}

check_cmd java
java -version 2>&1 | head -1

echo ""
check_cmd hadoop
hadoop version 2>/dev/null | head -1

echo ""
check_cmd hive
hive --version 2>/dev/null | head -1

echo ""
check_cmd sqoop
sqoop version 2>/dev/null | head -1

echo ""
check_cmd mysql

echo ""
echo "===== HDFS 状态 ====="
jps 2>/dev/null | grep -E "NameNode|DataNode|ResourceManager|NodeManager" || echo "  请先执行 start-dfs.sh 和 start-yarn.sh"

echo ""
echo "===== 环境检查完成 ====="
