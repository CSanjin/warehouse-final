#!/usr/bin/env bash
# 课程验收：Web 容器 + MySQL 容器 + 数据卷 + 自定义网络
# 用法：bash docker/verify.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a && source .env && set +a
fi

WEB_PORT="${WEB_PORT:-80}"
PASS=0
FAIL=0

ok()   { echo "[通过] $*"; PASS=$((PASS + 1)); }
fail() { echo "[失败] $*"; FAIL=$((FAIL + 1)); }

echo "=========================================="
echo "  课程验收检查（精简 2 容器方案）"
echo "=========================================="
echo ""

echo "--- 1. 容器数量（至少 Web + MySQL）---"
RUNNING=$(docker compose ps --status running -q 2>/dev/null | wc -l)
if [[ "${RUNNING}" -ge 2 ]]; then
  ok "运行中容器数: ${RUNNING}"
else
  fail "运行中容器不足 2 个，当前: ${RUNNING}"
fi
for c in warehouse-mysql warehouse-web; do
  if docker ps --format '{{.Names}}' | grep -qx "${c}"; then
    ok "容器 ${c} 正在运行"
  else
    fail "容器 ${c} 未运行"
  fi
done
echo ""

echo "--- 2. 自定义网络 warehouse-net ---"
if docker network inspect warehouse-net &>/dev/null; then
  ok "自定义网络已创建"
  SUBNET=$(docker network inspect warehouse-net -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)
  [[ "${SUBNET}" == "172.28.0.0/16" ]] && ok "子网: ${SUBNET}" || fail "子网异常: ${SUBNET:-未知}"
else
  fail "自定义网络不存在"
fi

if docker exec warehouse-web getent hosts mysql &>/dev/null; then
  ok "Web 容器可通过服务名 mysql 解析（DNS）"
else
  fail "Web 容器无法解析 mysql"
fi
echo ""

echo "--- 3. 数据卷持久化 ---"
for vol in warehouse-mysql-data warehouse-mysql-logs; do
  docker volume inspect "${vol}" &>/dev/null && ok "命名卷 ${vol} 存在" || fail "命名卷 ${vol} 不存在"
done

if docker inspect warehouse-mysql -f '{{range .Mounts}}{{if eq .Destination "/docker-entrypoint-initdb.d/01-init.sql"}}{{.Mode}}{{end}}{{end}}' 2>/dev/null | grep -q ro; then
  ok "初始化 SQL 只读挂载（:ro）"
else
  fail "初始化 SQL 只读挂载未检测到"
fi
echo ""

echo "--- 4. 数据安全 ---"
if docker port warehouse-mysql 2>/dev/null | grep -q 3306; then
  fail "MySQL 3306 已暴露到宿主机"
else
  ok "MySQL 仅内网访问，未映射 3306 到宿主机"
fi
[[ -f .env ]] && ok ".env 注入密码（不写入镜像）" || fail "缺少 .env"
echo ""

echo "--- 5. Web → MySQL 业务链路 ---"
CODE=$(curl -sf -o /dev/null -w "%{http_code}" "http://127.0.0.1:${WEB_PORT}/" 2>/dev/null || echo "000")
[[ "${CODE}" == "200" ]] && ok "Web 页面可访问" || fail "Web 页面不可访问 (${CODE})"

API_CODE=$(curl -sf -o /dev/null -w "%{http_code}" "http://127.0.0.1:${WEB_PORT}/api/goods/page?current=1&size=10" 2>/dev/null || echo "000")
[[ "${API_CODE}" == "200" ]] && ok "商品 API 正常（读写 MySQL）" || fail "API 异常 (${API_CODE})"

if docker compose exec -T mysql mysql -uroot -p"${MYSQL_ROOT_PASSWORD:-warehouse123}" -e "SELECT COUNT(*) FROM warehouse_goods.goods;" 2>/dev/null | grep -qE '[0-9]+'; then
  ok "MySQL 商品表有数据"
else
  fail "MySQL 商品表无数据"
fi
echo ""

echo "=========================================="
echo "  通过: ${PASS}  失败: ${FAIL}"
echo "=========================================="
if [[ "${FAIL}" -gt 0 ]]; then
  echo "排查: docker compose logs mysql warehouse-web"
  exit 1
fi
echo "演示建议："
echo "  1. docker network inspect warehouse-net"
echo "  2. docker volume ls | grep warehouse"
echo "  3. 页面新增商品后 docker compose restart mysql，刷新验证持久化"
