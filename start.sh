#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
if ! command -v mvn >/dev/null 2>&1; then
  echo "[ERROR] 未找到 Maven。请安装 Maven 3.9+ 并加入 PATH，或用 IDE 运行 CropNutritionApplication。"
  echo "下载地址：https://maven.apache.org/download.cgi"
  exit 1
fi
echo "正在启动禾智诊后端，首次运行需下载依赖..."
exec mvn spring-boot:run
