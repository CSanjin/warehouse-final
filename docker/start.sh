#!/usr/bin/env bash
# Ubuntu / Linux 一键构建并启动 Docker 集群
# 用法：bash docker/start.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v docker &>/dev/null; then
  echo "未检测到 Docker，请先执行：sudo bash docker/install-docker-ubuntu.sh"
  exit 1
fi

if ! docker compose version &>/dev/null; then
  echo "未检测到 Docker Compose 插件，请重新安装 Docker。"
  exit 1
fi

if [[ ! -f .env ]]; then
  cp docker/.env.example .env
  echo "已创建 .env（数据库密码等），可按需修改后重新运行。"
fi
# shellcheck disable=SC1091
set -a && source .env && set +a

# 检查可用内存（完整集群建议 >= 6GB）
MEM_MB=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
if [[ "${MEM_MB}" -gt 0 && "${MEM_MB}" -lt 6144 ]]; then
  echo "警告：可用内存约 ${MEM_MB}MB，低于建议 6GB，构建/启动可能较慢或 OOM。"
fi

echo "==> 构建并启动集群（首次约 15~30 分钟）..."
docker compose up -d --build

echo ""
echo "==> 等待 MySQL 就绪..."
for i in $(seq 1 60); do
  if docker compose exec -T mysql mysqladmin ping -h 127.0.0.1 -uroot -p"${MYSQL_ROOT_PASSWORD:-warehouse123}" &>/dev/null; then
    echo "MySQL 已就绪。"
    break
  fi
  if [[ "${i}" -eq 60 ]]; then
    echo "MySQL 启动超时，请检查：docker compose logs mysql"
    exit 1
  fi
  sleep 5
done

VM_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
VM_IP="${VM_IP:-localhost}"

echo ""
echo "集群已启动。常用命令："
echo "  docker compose ps"
echo "  docker compose logs -f warehouse-web warehouse-gateway"
echo "  bash docker/verify.sh"
echo ""
echo "访问地址："
echo "  Web 前端:  http://${VM_IP}"
echo "  API 网关:  http://${VM_IP}:8070/api/goods/page?current=1&size=10"
echo "  Nacos:     http://${VM_IP}:8848/nacos"
