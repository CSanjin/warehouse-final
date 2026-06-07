#!/usr/bin/env bash
# 课程验收：验证自定义网络、数据卷、Web + MySQL 链路
# 用法：bash docker/verify.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a && source .env && set +a
fi

PASS=0
FAIL=0

ok()   { echo "[通过] $*"; PASS=$((PASS + 1)); }
fail() { echo "[失败] $*"; FAIL=$((FAIL + 1)); }

echo "=========================================="
echo "  仓储系统 Docker 课程验收检查"
echo "=========================================="
echo ""

# ---------- 1. 容器运行状态 ----------
echo "--- 1. 核心容器状态（Web + 数据库）---"
for c in warehouse-mysql warehouse-web warehouse-gateway; do
  if docker ps --format '{{.Names}}' | grep -qx "${c}"; then
    ok "容器 ${c} 正在运行"
  else
    fail "容器 ${c} 未运行"
  fi
done
echo ""

# ---------- 2. 自定义网络 ----------
echo "--- 2. 自定义网络 warehouse-net ---"
if docker network inspect warehouse-net &>/dev/null; then
  ok "自定义网络 warehouse-net 已创建"
  SUBNET=$(docker network inspect warehouse-net -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)
  if [[ "${SUBNET}" == "172.28.0.0/16" ]]; then
    ok "子网配置正确: ${SUBNET}"
  else
    fail "子网不符合预期，当前: ${SUBNET:-未知}"
  fi
  MYSQL_IP=$(docker network inspect warehouse-net -f '{{range .Containers}}{{if eq .Name "warehouse-mysql"}}{{.IPv4Address}}{{end}}{{end}}' 2>/dev/null | cut -d/ -f1)
  if [[ "${MYSQL_IP}" == "172.28.0.10" ]]; then
    ok "MySQL 固定 IP: ${MYSQL_IP}"
  else
    fail "MySQL 固定 IP 异常: ${MYSQL_IP:-未分配}"
  fi
else
  fail "自定义网络 warehouse-net 不存在"
fi

if docker exec warehouse-gateway getent hosts mysql &>/dev/null; then
  ok "Gateway 容器可通过服务名解析 MySQL（DNS + 自定义网络）"
else
  fail "Gateway 容器无法解析 MySQL 主机名"
fi
echo ""

# ---------- 3. 数据卷 ----------
echo "--- 3. 数据卷持久化 ---"
for vol in warehouse-mysql-data warehouse-mysql-logs; do
  if docker volume inspect "${vol}" &>/dev/null; then
    MOUNT=$(docker volume inspect "${vol}" -f '{{.Mountpoint}}' 2>/dev/null)
    ok "命名卷 ${vol} 存在（挂载点: ${MOUNT}）"
  else
    fail "命名卷 ${vol} 不存在"
  fi
done

if docker inspect warehouse-mysql -f '{{range .Mounts}}{{if eq .Destination "/docker-entrypoint-initdb.d/01-init.sql"}}{{.Mode}}{{end}}{{end}}' 2>/dev/null | grep -q ro; then
  ok "初始化 SQL 为只读挂载（:ro）"
else
  fail "初始化 SQL 只读挂载未检测到"
fi
echo ""

# ---------- 4. 数据安全：MySQL 不暴露宿主机 ----------
echo "--- 4. 数据安全 ---"
if docker port warehouse-mysql 2>/dev/null | grep -q 3306; then
  fail "MySQL 3306 已映射到宿主机（课程建议仅内网访问）"
else
  ok "MySQL 3306 未映射到宿主机，仅 warehouse-net 内可访问"
fi

if [[ -f .env ]]; then
  ok ".env 环境变量文件存在（密码不写入镜像）"
else
  fail "缺少 .env 文件"
fi
echo ""

# ---------- 5. 业务链路 ----------
echo "--- 5. Web → Gateway → 微服务 → MySQL ---"
if curl -sf -o /dev/null -w "%{http_code}" http://127.0.0.1/ | grep -qE '200|304'; then
  ok "Web 前端 HTTP 可访问 (http://127.0.0.1/)"
else
  fail "Web 前端不可访问"
fi

HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "http://127.0.0.1/api/goods/page?current=1&size=10" 2>/dev/null || echo "000")
if [[ "${HTTP_CODE}" == "200" ]]; then
  ok "Nginx 反向代理 API 正常 (/api/goods/page)"
else
  fail "API 代理异常，HTTP 状态: ${HTTP_CODE}（微服务可能仍在注册，稍后再试）"
fi

if docker compose exec -T mysql mysql -uroot -p"${MYSQL_ROOT_PASSWORD:-warehouse123}" -e "SHOW DATABASES LIKE 'warehouse_goods';" 2>/dev/null | grep -q warehouse_goods; then
  ok "MySQL 业务库 warehouse_goods 已初始化"
else
  fail "MySQL 业务库未初始化"
fi
echo ""

# ---------- 汇总 ----------
echo "=========================================="
echo "  通过: ${PASS}  失败: ${FAIL}"
echo "=========================================="
if [[ "${FAIL}" -gt 0 ]]; then
  echo "部分检查未通过，可执行 docker compose logs 排查。"
  exit 1
fi
echo "全部验收项通过。课程演示建议："
echo "  1. docker network inspect warehouse-net"
echo "  2. docker volume ls | grep warehouse"
echo "  3. 前端新增数据后执行 docker compose restart mysql，刷新验证持久化"
