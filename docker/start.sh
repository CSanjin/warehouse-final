#!/usr/bin/env bash
# Ubuntu 一键启动（精简版：Web + MySQL，约 5~10 分钟首次构建）
# 用法：bash docker/start.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v docker &>/dev/null; then
  echo "未检测到 Docker，请先安装：sudo apt-get install -y docker.io docker-compose-v2"
  exit 1
fi

if [[ ! -f .env ]]; then
  cp docker/.env.example .env
  echo "已创建 .env，默认数据库密码 warehouse123"
fi
# shellcheck disable=SC1091
set -a && source .env && set +a

echo "==> 启动精简集群（2 容器：warehouse-web + warehouse-mysql）..."
docker compose up -d --build

echo ""
echo "==> 等待服务就绪（最多 3 分钟）..."
for i in $(seq 1 36); do
  MYSQL_OK=0
  WEB_OK=0
  if docker compose exec -T mysql mysqladmin ping -h 127.0.0.1 -uroot -p"${MYSQL_ROOT_PASSWORD}" &>/dev/null; then
    MYSQL_OK=1
  fi
  if curl -sf "http://127.0.0.1:${WEB_PORT:-80}/api/goods/page?current=1&size=1" &>/dev/null; then
    WEB_OK=1
  fi
  if [[ "${MYSQL_OK}" -eq 1 && "${WEB_OK}" -eq 1 ]]; then
    echo "MySQL 与 Web 均已就绪。"
    break
  fi
  if [[ "${i}" -eq 36 ]]; then
    echo "启动较慢或超时，请查看日志："
    echo "  docker compose ps"
    echo "  docker compose logs mysql warehouse-web"
    exit 1
  fi
  printf "."
  sleep 5
done
echo ""

VM_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
VM_IP="${VM_IP:-localhost}"

echo ""
echo "部署完成！"
echo "  Web 页面:  http://${VM_IP}:${WEB_PORT:-80}/"
echo "  商品 API:  http://${VM_IP}:${WEB_PORT:-80}/api/goods/page?current=1&size=10"
echo ""
echo "验收命令: bash docker/verify.sh"
echo "查看状态: docker compose ps"
