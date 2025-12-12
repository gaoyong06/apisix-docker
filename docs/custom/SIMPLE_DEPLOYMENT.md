# APISIX 简化部署方案

## 核心思路

**使用官方镜像 + 配置文件挂载 + 插件独立服务**

- ✅ 无需构建自定义镜像
- ✅ 配置修改立即生效（无需重新构建）
- ✅ 插件独立运行，便于调试和维护
- ✅ 使用官方镜像，稳定可靠

## 方案架构

```
┌─────────────────┐
│  APISIX (官方镜像) │  ← 挂载配置文件
└────────┬────────┘
         │
         ├──> ext-plugin 调用
         │
┌─────────▼─────────┐
│ Plugin Runner     │  ← 独立服务，独立镜像
│ (Go 插件)         │
└───────────────────┘
```

## 实施步骤

### 1. 构建插件镜像（一次性）

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-devshare-plugin-runner

# 构建插件镜像
docker build -t xinyuan-tech/plugin-runner:latest .
```

**Dockerfile**（在 `apisix-devshare-plugin-runner` 目录下创建）：

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /build
COPY . .
RUN go mod download && \
    go build -o go-runner ./cmd/go-runner

FROM alpine:latest
RUN apk add --no-cache ca-certificates
COPY --from=builder /build/go-runner /usr/local/bin/go-runner
RUN chmod +x /usr/local/bin/go-runner
ENTRYPOINT ["/usr/local/bin/go-runner", "run"]
```

### 2. 创建简化的 docker-compose.yml

```yaml
version: "3.8"

services:
  # APISIX 网关（使用官方镜像）
  apisix:
    image: apache/apisix:3.14.1-debian
    restart: always
    volumes:
      # 挂载配置文件（修改后立即生效）
      - ./example/apisix_conf/config.yaml:/usr/local/apisix/conf/config.yaml:ro
    ports:
      - "9080:9080"   # HTTP
      - "9443:9443"   # HTTPS
      - "9180:9180"   # Admin API
      - "9091:9091"   # Prometheus
      - "9092:9092"   # Control API
    depends_on:
      - etcd
      - plugin-runner
    networks:
      - apisix-network
    environment:
      - APISIX_STAND_ALONE=false

  # Go Plugin Runner（独立服务）
  plugin-runner:
    image: xinyuan-tech/plugin-runner:latest
    restart: always
    networks:
      - apisix-network
    # 插件通过 ext-plugin 协议与 APISIX 通信
    # 无需额外配置

  # etcd 配置中心
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
    ports:
      - "2379:2379"
    networks:
      - apisix-network

networks:
  apisix-network:
    driver: bridge

volumes:
  etcd_data:
    driver: local
```

### 3. 修改 APISIX 配置

**关键修改**：`example/apisix_conf/config.yaml`

```yaml
# 外部插件配置（Go Plugin Runner）
ext-plugin:
  # 使用 Docker 服务名（在同一个网络中）
  cmd: ["/bin/sh", "-c", "exec /usr/local/bin/go-runner run"]
  # 或者使用网络调用（推荐）
  # 注意：ext-plugin 支持通过 Unix Socket 或 TCP 调用
```

**注意**：APISIX 的 ext-plugin 默认通过 Unix Socket 或进程调用。如果插件作为独立服务，需要：

**方案 A（推荐）**：使用官方镜像内置的 ext-plugin 调用方式

实际上，APISIX 的 ext-plugin 是通过子进程调用的，不是通过网络。所以我们需要：

1. **将插件二进制挂载到 APISIX 容器**：

```yaml
services:
  apisix:
    image: apache/apisix:3.14.1-debian
    volumes:
      - ./example/apisix_conf/config.yaml:/usr/local/apisix/conf/config.yaml:ro
      # 挂载插件二进制（从插件容器复制或构建）
      - ./apisix-devshare-plugin-runner/bin/go-runner:/usr/local/bin/go-runner:ro
    # ... 其他配置
```

2. **配置 ext-plugin**：

```yaml
ext-plugin:
  cmd: ["/usr/local/bin/go-runner", "run"]
```

## 最简方案（推荐）

### 方案：官方镜像 + 配置文件挂载 + 插件二进制挂载

**优点**：
- ✅ 最简单，无需构建自定义镜像
- ✅ 配置修改立即生效
- ✅ 使用官方镜像，稳定可靠
- ✅ 插件独立构建，便于维护

### 完整 docker-compose.yml

```yaml
version: "3.8"

services:
  apisix:
    image: apache/apisix:3.14.1-debian
    restart: always
    volumes:
      # 配置文件（修改后重启容器即可生效）
      - ./example/apisix_conf/config.yaml:/usr/local/apisix/conf/config.yaml:ro
      # 插件二进制（构建一次，挂载使用）
      - ./apisix-devshare-plugin-runner/bin/go-runner:/usr/local/bin/go-runner:ro
    ports:
      - "9080:9080"
      - "9443:9443"
      - "9180:9180"
      - "9091:9091"
      - "9092:9092"
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
    ports:
      - "2379:2379"
    networks:
      - apisix-network

networks:
  apisix-network:
    driver: bridge

volumes:
  etcd_data:
    driver: local
```

### 配置文件

**example/apisix_conf/config.yaml**：

```yaml
apisix:
  node_listen: 9080
  enable_ipv6: false
  enable_control: true
  control:
    ip: "0.0.0.0"
    port: 9092

deployment:
  admin:
    allow_admin:
      - 0.0.0.0/0  # 生产环境请限制 IP
    admin_key:
      - name: "admin"
        key: xinyuan_tech_apisix_admin_key_2025_secure
        role: admin
      - name: "viewer"
        key: xinyuan_tech_apisix_viewer_key_2025_secure
        role: viewer
  etcd:
    host:
      - "http://etcd:2379"
    prefix: "/apisix"
    timeout: 30

plugin_attr:
  prometheus:
    export_addr:
      ip: "0.0.0.0"
      port: 9091

# 外部插件配置（最简单的方式）
ext-plugin:
  cmd: ["/usr/local/bin/go-runner", "run"]
```

## 使用流程

### 1. 构建插件（一次性）

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-devshare-plugin-runner
make build
# 或
go build -o bin/go-runner ./cmd/go-runner
```

### 2. 启动服务

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-docker/example
docker-compose up -d
```

### 3. 修改配置

```bash
# 修改配置文件
vim apisix_conf/config.yaml

# 重启 APISIX（配置会自动重新加载）
docker-compose restart apisix
```

### 4. 更新插件

```bash
# 重新构建插件
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-devshare-plugin-runner
make build

# 重启 APISIX（会使用新的插件二进制）
docker-compose restart apisix
```

## 生产环境部署

### 1. 准备文件

```bash
# 构建插件
cd apisix-devshare-plugin-runner
make build

# 复制到部署目录
mkdir -p /opt/apisix/{config,plugins}
cp example/apisix_conf/config.yaml /opt/apisix/config/
cp apisix-devshare-plugin-runner/bin/go-runner /opt/apisix/plugins/
```

### 2. 部署

```bash
cd /opt/apisix
docker-compose up -d
```

### 3. 验证

```bash
# 检查服务状态
docker-compose ps

# 检查 APISIX 状态
curl http://localhost:9180/apisix/admin/services \
  -H "X-API-KEY: your-admin-key"
```

## 优势对比

| 方案 | 复杂度 | 灵活性 | 维护成本 | 推荐度 |
|------|--------|--------|----------|--------|
| **简化方案**（推荐） | ⭐ 低 | ⭐⭐⭐ 高 | ⭐ 低 | ⭐⭐⭐⭐⭐ |
| 自定义镜像 | ⭐⭐⭐ 高 | ⭐⭐ 中 | ⭐⭐⭐ 高 | ⭐⭐ |
| 插件独立服务 | ⭐⭐ 中 | ⭐⭐⭐ 高 | ⭐⭐ 中 | ⭐⭐⭐ |

## 常见问题

### Q: 插件如何更新？

**A**: 重新构建插件二进制，重启 APISIX 容器即可。

```bash
cd apisix-devshare-plugin-runner
make build
docker-compose restart apisix
```

### Q: 配置如何更新？

**A**: 修改配置文件，重启 APISIX 容器。

```bash
vim apisix_conf/config.yaml
docker-compose restart apisix
```

### Q: 如何回滚？

**A**: 使用 Git 版本控制，回滚配置文件即可。

```bash
git checkout previous-version -- apisix_conf/config.yaml
docker-compose restart apisix
```

## 总结

**最简方案**：
1. ✅ 使用官方 APISIX 镜像
2. ✅ 配置文件挂载
3. ✅ 插件二进制挂载
4. ✅ 无需构建自定义镜像
5. ✅ 配置修改立即生效

**这就是最简单、最容易、最不容易出错的方案！**
