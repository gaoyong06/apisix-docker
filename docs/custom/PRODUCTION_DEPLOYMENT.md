# APISIX 生产环境部署指南

## 概述

本文档说明如何将自定义 APISIX 配置和插件部署到生产环境。

## 前置条件

1. Docker 和 Docker Compose 已安装
2. 私有容器镜像仓库（可选，推荐）
3. 配置管理工具（Ansible/Terraform，可选）

## 部署方案

### 方案 A: 使用自定义 Docker 镜像（推荐）

#### 1. 构建自定义镜像

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-docker

# 构建包含插件和配置的自定义镜像
docker build -f Dockerfile.custom -t xinyuan-tech/apisix:3.14.1-custom .
```

#### 2. 推送到镜像仓库

```bash
# 标记镜像
docker tag xinyuan-tech/apisix:3.14.1-custom \
  registry.example.com/xinyuan-tech/apisix:3.14.1-custom

# 推送镜像
docker push registry.example.com/xinyuan-tech/apisix:3.14.1-custom
```

#### 3. 生产环境部署

```yaml
# docker-compose.prod.yml
version: "3.8"

services:
  apisix:
    image: registry.example.com/xinyuan-tech/apisix:3.14.1-custom
    restart: always
    ports:
      - "9080:9080"
      - "9443:9443"
      - "9180:9180"
    depends_on:
      - etcd
    networks:
      - apisix-network
    environment:
      - APISIX_STAND_ALONE=false

  etcd:
    image: bitnamilegacy/etcd:3.5.11
    restart: always
    volumes:
      - etcd_data:/bitnami/etcd
    environment:
      ETCD_ENABLE_V2: "true"
      ALLOW_NONE_AUTHENTICATION: "yes"
      ETCD_ADVERTISE_CLIENT_URLS: "http://etcd:2379"
      ETCD_LISTEN_CLIENT_URLS: "http://0.0.0.0:2379"
    networks:
      - apisix-network

networks:
  apisix-network:
    driver: bridge

volumes:
  etcd_data:
    driver: local
```

```bash
# 启动服务
docker-compose -f docker-compose.prod.yml up -d

# 验证部署
curl http://localhost:9180/apisix/admin/services \
  -H "X-API-KEY: your-admin-key"
```

### 方案 B: 配置文件挂载（推荐用于配置频繁变更）

#### 1. 构建插件镜像

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-devshare-plugin-runner

# 构建插件 Runner 镜像
docker build -f Dockerfile -t xinyuan-tech/plugin-runner:latest .
```

#### 2. 生产环境部署

```yaml
# docker-compose.prod.yml
version: "3.8"

services:
  apisix:
    image: apache/apisix:3.14.1-debian
    restart: always
    volumes:
      - ./example/apisix_conf/config.yaml:/usr/local/apisix/conf/config.yaml:ro
    ports:
      - "9080:9080"
      - "9443:9443"
      - "9180:9180"
    depends_on:
      - etcd
      - plugin-runner
    networks:
      - apisix-network

  plugin-runner:
    image: registry.example.com/xinyuan-tech/plugin-runner:latest
    restart: always
    networks:
      - apisix-network
    # 插件运行配置

  etcd:
    image: bitnamilegacy/etcd:3.5.11
    restart: always
    volumes:
      - etcd_data:/bitnami/etcd
    environment:
      ETCD_ENABLE_V2: "true"
      ALLOW_NONE_AUTHENTICATION: "yes"
      ETCD_ADVERTISE_CLIENT_URLS: "http://etcd:2379"
      ETCD_LISTEN_CLIENT_URLS: "http://0.0.0.0:2379"
    networks:
      - apisix-network

networks:
  apisix-network:
    driver: bridge

volumes:
  etcd_data:
    driver: local
```

## CI/CD 集成

### GitHub Actions 示例

```yaml
# .github/workflows/deploy-production.yml
name: Deploy to Production

on:
  push:
    branches:
      - main
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Build and push image
        run: |
          docker build -f Dockerfile.custom -t xinyuan-tech/apisix:${{ github.sha }} .
          docker push xinyuan-tech/apisix:${{ github.sha }}
      
      - name: Deploy to production
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.PROD_HOST }}
          username: ${{ secrets.PROD_USER }}
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /opt/apisix
            docker-compose pull
            docker-compose up -d
            docker-compose ps
```

## 配置管理

### 环境变量配置

```bash
# .env.production
APISIX_ADMIN_KEY=your-secure-admin-key
APISIX_IMAGE_TAG=3.14.1-custom
ETCD_HOST=etcd:2379
```

### 配置版本控制

1. **配置文件 Git 管理**：
   ```bash
   git add example/apisix_conf/config.yaml
   git commit -m "Update APISIX configuration for production"
   git tag -a v1.0.0 -m "Production release v1.0.0"
   ```

2. **配置变更流程**：
   - 开发环境测试
   - 预发布环境验证
   - 生产环境部署
   - 回滚机制

## 监控和日志

### 健康检查

```bash
# 检查 APISIX 状态
curl http://localhost:9180/apisix/admin/routes \
  -H "X-API-KEY: your-admin-key"

# 检查插件状态
docker logs apisix-plugin-runner
```

### 日志收集

```yaml
# docker-compose.prod.yml
services:
  apisix:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

## 安全建议

1. **Admin API Key**：
   - 使用强密码
   - 定期轮换
   - 限制访问 IP

2. **网络隔离**：
   - 使用 Docker 网络隔离
   - 限制端口暴露

3. **镜像安全**：
   - 定期扫描漏洞
   - 使用官方基础镜像
   - 及时更新依赖

## 回滚策略

```bash
# 回滚到上一个版本
docker-compose -f docker-compose.prod.yml down
docker pull registry.example.com/xinyuan-tech/apisix:previous-version
docker-compose -f docker-compose.prod.yml up -d
```

## 参考

- [APISIX 官方文档](https://apisix.apache.org/zh/docs/apisix/installation-guide/)
- [Docker 最佳实践](https://docs.docker.com/develop/dev-best-practices/)
- [CI/CD 最佳实践](https://www.atlassian.com/continuous-delivery/principles/continuous-integration-vs-delivery-vs-deployment)
