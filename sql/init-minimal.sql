-- 课程精简版：仅初始化商品库（加快 MySQL 首次启动）
CREATE DATABASE IF NOT EXISTS warehouse_goods DEFAULT CHARACTER SET utf8mb4;

USE warehouse_goods;

CREATE TABLE IF NOT EXISTS goods (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    goods_code VARCHAR(64) NOT NULL,
    goods_name VARCHAR(128) NOT NULL,
    category VARCHAR(64),
    unit VARCHAR(16),
    price DECIMAL(12,2),
    spec VARCHAR(128),
    status INT DEFAULT 1,
    create_time DATETIME,
    update_time DATETIME,
    create_by VARCHAR(64),
    update_by VARCHAR(64),
    deleted INT DEFAULT 0
);

INSERT INTO goods(goods_code, goods_name, category, unit, price, status)
VALUES ('G001', '螺丝M8', '五金', '个', 0.50, 1);
