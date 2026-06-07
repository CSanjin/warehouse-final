# Docker 容器化与集群部署说明

本目录包含仓储微服务系统的 **Docker Compose 集群** 配置，满足课程设计中「Web 应用 + 数据库 + 数据卷 + 自定义网络」的要求。

## 一、容器架构

| 类型 | 容器 | 说明 |
|------|------|------|
| **Web 应用** | `warehouse-web` | Vue3 前端 + Nginx（对外端口 80） |
| **Web 后端** | `warehouse-gateway` | Spring Cloud Gateway（8070） |
| **数据库** | `warehouse-mysql` | MySQL 8.0，6 个业务库 |
| 微服务 | `warehouse-user` 等 6 个 | 用户/商品/仓库/库存/出入库/盘点 |
| 中间件 | `nacos`、`rocketmq-*`、`sentinel` | 注册中心、消息队列、流控 |

**课程最低要求（Web + DB）**：`warehouse-web` + `warehouse-mysql` 两个核心容器；完整运行需依赖网关与微服务集群。

## 二、数据安全与数据卷设计

| 卷名 | 类型 | 用途 |
|------|------|------|
| `warehouse-mysql-data` | 命名卷 | MySQL 数据文件持久化（`/var/lib/mysql`） |
| `warehouse-mysql-logs` | 命名卷 | binlog / 日志，支持数据恢复演示 |
| `warehouse-nacos-data` | 命名卷 | Nacos 配置与注册数据 |
| `warehouse-rocketmq-broker-store` | 命名卷 | MQ 消息持久化 |
| `./sql/init.sql` | **只读** bind mount | 首次启动初始化库表，容器内不可改 |
| `./docker/mysql/conf.d` | **只读** bind mount | MySQL 安全与字符集配置 |

**安全措施：**

1. 数据库密码通过 `.env` 注入，**不写入镜像**
2. MySQL **默认不映射** 3306 到宿主机，仅 `warehouse-net` 内网访问
3. 初始化 SQL **只读挂载**（`:ro`）
4. Java 容器以非 root 用户 `warehouse` 运行
5. `custom.cnf` 开启 binlog，便于演示备份恢复

## 三、自定义网络设计

```yaml
networks:
  warehouse-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
          gateway: 172.28.0.1
```

| 容器 | 固定 IP（示例） | 角色 |
|------|----------------|------|
| mysql | 172.28.0.10 | 数据层 |
| nacos | 172.28.0.11 | 注册中心 |
| gateway | 172.28.0.20 | API 入口 |
| warehouse-web | 172.28.0.21 | Web 入口 |

服务间通过 **容器名** 通信（如 `jdbc:mysql://mysql:3306/...`），与宿主机 IP 解耦。

## 四、Ubuntu 虚拟机部署（推荐用于课程设计）

### 4.1 虚拟机环境要求

| 项目 | 建议 |
|------|------|
| 系统 | Ubuntu 22.04 / 24.04 LTS |
| CPU | 4 核及以上 |
| 内存 | **8GB** 及以上（完整集群含 7 个 Java 微服务） |
| 磁盘 | 40GB 及以上 |
| 网络 | 能访问 Docker Hub（或配置国内镜像加速） |

### 4.2 安装 Docker（首次执行）

将项目上传到虚拟机后，在项目根目录执行：

```bash
sudo bash docker/install-docker-ubuntu.sh
# 将当前用户加入 docker 组后，注销并重新登录
```

### 4.3 一键启动集群

```bash
cd /path/to/warehouse-cursor-第一版
chmod +x docker/start.sh docker/verify.sh
bash docker/start.sh
```

等价于：

```bash
cp docker/.env.example .env    # 首次
docker compose up -d --build
```

首次构建约 **15~30 分钟**（Maven 编译 7 个微服务 + 前端 npm build）。

### 4.4 防火墙（若启用了 ufw）

```bash
sudo ufw allow 80/tcp      # Web 前端
sudo ufw allow 8070/tcp    # API 网关（可选，调试用）
sudo ufw allow 8848/tcp    # Nacos（可选）
```

### 4.5 课程验收演示

```bash
bash docker/verify.sh
```

手动演示数据卷：在前端新增商品后执行 `docker compose restart mysql`，刷新页面数据应仍在。

手动演示网络：`docker network inspect warehouse-net` 查看子网 `172.28.0.0/16` 与各容器固定 IP。

## 五、Windows 快速启动

### 前置条件

- Docker Desktop 20.10+
- Docker Compose v2
- 至少 **8GB** 可用内存

### 步骤

```powershell
# 1. 进入项目根目录
cd "e:\code\Spring cloud\warehouse-cursor-第一版"

# 2. 一键启动
.\docker\start.ps1

# 3. 查看状态
docker compose ps
docker compose logs -f warehouse-gateway warehouse-web
```

### 访问地址

| 服务 | 地址 |
|------|------|
| **Web 前端** | http://虚拟机IP 或 http://localhost |
| API 网关 | http://虚拟机IP:8070/api/goods/page |
| Nacos | http://虚拟机IP:8848/nacos |
| Sentinel | http://虚拟机IP:8858 |

## 六、课程演示命令

### 1. 验证自定义网络

```powershell
docker network inspect warehouse-net
docker exec warehouse-web ping -c 2 mysql
```

### 2. 验证数据卷持久化

```powershell
# 查看卷
docker volume ls | findstr warehouse

# 在前端新增一条商品后，重启 MySQL 容器
docker compose restart mysql

# 数据应仍然存在
```

### 3. 验证 Web → Gateway → 微服务 → MySQL 链路

```powershell
curl http://localhost/api/goods/page?current=1^&size=10
```

### 4. 查看容器资源

```powershell
docker stats --no-stream
```

## 七、常用运维

```powershell
# 停止集群（保留数据卷）
docker compose down

# 停止并删除数据卷（清空数据库，慎用）
docker compose down -v

# 仅重建 Web 容器
docker compose up -d --build warehouse-web

# 进入 MySQL 容器
docker exec -it warehouse-mysql mysql -uroot -p
```

## 八、故障排查

| 现象 | 处理 |
|------|------|
| 502 / 连接失败 | 等待微服务注册到 Nacos：`docker compose logs warehouse-gateway` |
| MySQL 启动失败 | 检查 `.env` 中密码；删除损坏卷：`docker volume rm warehouse-mysql-data` 后重建 |
| 构建超时 | 配置 Maven 镜像；或本地 `mvn package` 后调整 Dockerfile 直接 COPY jar |
| 80 端口占用 | 修改 `.env` 中 `WEB_PORT=8088` |

## 九、目录结构

```
docker/
├── Dockerfile.service       # Java 微服务通用镜像
├── Dockerfile.web           # Vue + Nginx Web 镜像
├── nginx/nginx.conf         # 反向代理 Gateway
├── mysql/conf.d/            # MySQL 配置（只读挂载）
├── rocketmq/broker.conf     # MQ Broker 配置
├── .env.example             # 环境变量模板
├── install-docker-ubuntu.sh # Ubuntu 安装 Docker
├── start.sh                 # Linux 一键启动
├── start.ps1                # Windows 一键启动
├── verify.sh                # 课程验收脚本
└── README.md                # 本文档
docker-compose.yml           # 集群编排文件（项目根目录）
```

## 十、课程设计要点对照

| 课程要求 | 本项目实现 |
|----------|------------|
| Web 应用容器 + 数据库容器（至少 2 个） | `warehouse-web`（Nginx+Vue）+ `warehouse-mysql` |
| 数据卷与数据安全 | 命名卷 `mysql-data`/`mysql-logs`；初始化 SQL 只读挂载；密码经 `.env` 注入 |
| 自定义网络 | `warehouse-net` 桥接网 `172.28.0.0/16`，固定 IP，服务名 DNS 解析 |
| 集群化 | 7 个业务微服务 + Gateway + Nacos + RocketMQ + Sentinel |
