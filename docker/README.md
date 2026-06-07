# Docker 容器化部署说明（课程精简版）

满足课程最低要求：**Web 容器 + MySQL 容器 + 数据卷 + 自定义网络**，仅 2 个容器，虚拟机 4GB 内存即可运行。

## 架构

| 容器 | 说明 | 固定 IP |
|------|------|---------|
| `warehouse-mysql` | MySQL 8.0，命名卷持久化 | 172.28.0.10 |
| `warehouse-web` | Spring Boot（页面 + 商品 API） | 172.28.0.21 |

自定义网络：`warehouse-net`（`172.28.0.0/16`）

## Ubuntu 虚拟机部署

### 1. 安装 Docker（已安装可跳过）

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2 curl
sudo usermod -aG docker $USER
newgrp docker
```

### 2. 进入项目并启动

```bash
cd ~/warehouse-cursor
cp docker/.env.example .env
bash docker/start.sh
```

或手动：

```bash
docker compose up -d --build
```

首次构建约 **5~10 分钟**（仅编译 1 个 Java 模块，无 Nacos/Vue 构建）。

### 3. 验收

```bash
bash docker/verify.sh
```

浏览器访问：`http://虚拟机IP/`

### 4. 课程演示

```bash
# 自定义网络
docker network inspect warehouse-net

# 数据卷
docker volume ls | grep warehouse

# 数据持久化：页面新增商品后重启 MySQL
docker compose restart mysql
# 刷新页面，数据仍在
```

## 课程要求对照

| 要求 | 实现 |
|------|------|
| Web + 数据库（≥2 容器） | `warehouse-web` + `warehouse-mysql` |
| 数据卷 | `warehouse-mysql-data`、`warehouse-mysql-logs`；init.sql 只读挂载 |
| 自定义网络 | `warehouse-net` 桥接网 + 固定 IP + 服务名 DNS |
| 数据安全 | 密码 `.env` 注入；MySQL 不映射 3306 到宿主机 |

## 完整微服务集群（可选）

需要 Nacos + 7 个微服务 + Gateway + Vue 时：

```bash
docker compose -f docker-compose.full.yml up -d --build
```

建议内存 **8GB+**，首次构建约 30 分钟。

## 常用命令

```bash
docker compose ps
docker compose logs -f warehouse-web mysql
docker compose down          # 停止，保留数据卷
docker compose down -v       # 停止并清空数据库（慎用）
```

## 故障排查

| 现象 | 处理 |
|------|------|
| 构建慢 | 已配置阿里云 Maven 镜像；检查网络 |
| Web 启动失败 | `docker compose logs warehouse-web` 查看 Nacos 相关可忽略 |
| 80 端口占用 | `.env` 中设置 `WEB_PORT=8088` |
| 旧数据冲突 | `docker compose down -v` 后重建 |
