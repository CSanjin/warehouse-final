#!/usr/bin/env bash
# Ubuntu 22.04 / 24.04 安装 Docker Engine + Compose 插件
# 用法：sudo bash docker/install-docker-ubuntu.sh

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "请使用 root 权限运行：sudo bash $0"
  exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
if [[ "${REAL_USER}" == "root" ]]; then
  echo "警告：未检测到 SUDO_USER，安装后请手动将用户加入 docker 组。"
fi

echo "==> 卸载旧版本（如有）..."
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

echo "==> 安装依赖..."
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

echo "==> 添加 Docker 官方 GPG 密钥..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "==> 添加 Docker APT 源..."
CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  ${CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "==> 安装 Docker Engine 与 Compose 插件..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> 配置国内镜像加速（可选，加速拉取镜像）..."
mkdir -p /etc/docker
if [[ ! -f /etc/docker/daemon.json ]]; then
  cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.m.daocloud.io"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
  systemctl restart docker
fi

echo "==> 启动并设置开机自启..."
systemctl enable docker
systemctl start docker

if [[ "${REAL_USER}" != "root" ]]; then
  echo "==> 将用户 ${REAL_USER} 加入 docker 组..."
  usermod -aG docker "${REAL_USER}"
fi

echo ""
docker --version
docker compose version
echo ""
echo "Docker 安装完成。"
if [[ "${REAL_USER}" != "root" ]]; then
  echo "请注销并重新登录（或执行 newgrp docker），然后运行："
  echo "  bash docker/start.sh"
fi
