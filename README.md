# 仓储微服务系统 (warehouse-microservice)

基于 Spring Boot 2.7.15 + Spring Cloud Alibaba 2021.0.4.0 的仓储管理微服务脚手架。

## 模块结构

```
warehouse-microservice
├── warehouse-common    公共模块
├── warehouse-gateway   网关 + Sentinel
├── warehouse-user      用户&权限
├── warehouse-goods     商品
├── warehouse-base      仓库基础
├── warehouse-stock     库存核心 + MQ消费
├── warehouse-inout     出入库 + MQ生产
└── warehouse-check     盘点 + MQ生产
```

## 环境依赖

| 组件 | 地址 |
|------|------|
| Nacos | 127.0.0.1:8848 |
| Sentinel 控制台 | 127.0.0.1:8858 |
| RocketMQ NameServer | 127.0.0.1:9876 |
| Seata Server（分布式事务，inout/stock） | 注册到 Nacos，集群名 `default` |
| MySQL | 127.0.0.1:3306 用户 root |

### Seata 启动说明（inout 模块必需）

1. 启动 Nacos（8848）
2. 启动 Seata Server（TC），并确保在 Nacos 中注册为 **`seata-server`**，分组 **`SEATA_GROUP`**，集群名为 **`default`**
3. 在 `warehouse_inout`、`warehouse_stock` 库执行 `sql/init.sql` 中的 **`undo_log`** 表
4. 若暂未部署 Seata，可在 `warehouse-inout` / `warehouse-stock` 的 `application.yml` 中设置 `seata.enabled: false`（将无法使用 `@GlobalTransactional` 分布式事务）

### JDK 版本说明

- 项目编译目标为 **Java 8**；Docker 镜像使用 Temurin 8 JRE。
- 若在本地使用 **JDK 17+**（含 JDK 22/23）通过 IDE 启动 `warehouse-inout` / `warehouse-stock`，需在 VM Options 中加入：
  ```
  --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.lang.reflect=ALL-UNNAMED
  ```
  项目已在 `.run/InoutApplication.run.xml`、`.run/StockApplication.run.xml` 及 `mvn spring-boot:run` 中预置该参数（Seata 依赖的 cglib 在 JDK 17+ 上需要）。

## 快速启动

1. 执行 `sql/init.sql` 初始化数据库
2. 启动 Nacos、Sentinel Dashboard、RocketMQ、MySQL
3. 在项目根目录编译：

```bash
mvn clean install -DskipTests
```

4. 依次启动（或通过 IDE 运行 main）：

- `warehouse-user` → 8081
- `warehouse-goods` → 8082
- `warehouse-base` → 8083
- `warehouse-stock` → 8084
- `warehouse-inout` → 8085
- `warehouse-check` → 8086
- `warehouse-gateway` → 8070（8080 为 Sentinel Dashboard 默认端口，避免冲突）

## 网关 API 示例

- 用户分页：`GET http://127.0.0.1:8070/api/user/users/page`
- 商品分页：`GET http://127.0.0.1:8070/api/goods/page`
- 仓库分页：`GET http://127.0.0.1:8070/api/base/warehouses/page`
- 库存分页：`GET http://127.0.0.1:8070/api/stock/page`
- 创建入库单：`POST http://127.0.0.1:8070/api/inout` Body: `{"orderType":"IN","warehouseId":1,"goodsId":1,"quantity":100,"operator":"admin"}`
- 确认出入库：`POST http://127.0.0.1:8070/api/inout/confirm/{id}` （异步 MQ 更新库存）
- 盘点确认：`POST http://127.0.0.1:8070/api/check/confirm/{id}`

## 技术要点

- 统一返回 `Result<T>`、全局异常、Sentinel 流控返回 Result 格式
- MyBatis-Plus 逻辑删除 + 自动填充 `BaseEntity`
- Feign + Sentinel 熔断降级
- RocketMQ Topic: `warehouse-stock-update-topic` 异步更新库存

## Docker 容器化部署（Ubuntu 虚拟机 / Windows）

项目提供 Docker Compose 集群方案，满足课程设计：**Web 容器 + MySQL 容器 + 数据卷 + 自定义网络**。

**Ubuntu 虚拟机：**

```bash
sudo bash docker/install-docker-ubuntu.sh   # 首次安装 Docker
bash docker/start.sh                        # 构建并启动集群
bash docker/verify.sh                       # 验收演示
```

**Windows：**

```powershell
.\docker\start.ps1
```

- Web 访问：`http://<虚拟机IP>` 或 `http://localhost`
- 详细说明见 [docker/README.md](docker/README.md)
