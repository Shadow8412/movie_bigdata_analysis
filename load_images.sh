#!/bin/bash
# =============================================================================
# Ubuntu 端：加载从 Windows 导出的 Docker 镜像
# 用法: bash load_images.sh
# =============================================================================
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "  加载 Docker 镜像 (从 Windows 导入)"
echo "============================================"

if [ ! -d "$DIR/images_export" ]; then
    echo "[错误] 找不到 images_export 目录"
    echo "请先把 Windows 上导出的 images_export 文件夹放到此目录"
    exit 1
fi

for tarfile in "$DIR/images_export"/*.tar; do
    [ -f "$tarfile" ] || continue
    fname=$(basename "$tarfile")
    echo "[导入] $fname  ($(du -h "$tarfile" | cut -f1))"
    docker load -i "$tarfile"
    echo ""
done

echo "============================================"
echo "  导入完成！查看已加载的镜像："
echo "============================================"
docker images | grep -E "hadoop|hive|postgres|mysql"
echo ""
echo "现在可以运行: bash test.sh"
