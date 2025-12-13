# Short Link Service APISIX 路由配置指南

## 概述

本文档说明如何配置 APISIX Gateway 以支持 short-link-service。

## 前置条件

1. APISIX Gateway 已启动并运行
2. short-link-service 已启动并运行（默认端口：8110）
3. etcd 已启动并运行（APISIX 配置存储）
4. 已安装 `curl` 和 `jq` 工具

## 快速配置

### 1. 运行配置脚本

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-docker
./scripts/setup-short-link-service.sh
```

### 2. 环境变量配置（可选）

如果 short-link-service 不在默认位置，可以设置环境变量：

```bash
export SHORT_LINK_SERVICE_HOST=127.0.0.1
export SHORT_LINK_SERVICE_PORT=8110
export APISIX_ADMIN_URL=http://127.0.0.1:9180
export APISIX_ADMIN_KEY=edd1c9f034335f136f87ad84b625c8f1

./scripts/setup-short-link-service.sh
```

## 配置说明

### 路由配置

脚本会创建以下路由：

1. **API 路由** (`/v1/short-link*`)
   - 路径：`/v1/short-link*`
   - 方法：GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
   - 认证：需要 API Key（通过 `api-key` 插件）
   - 计费：需要计费（通过 `billing` 插件）
   - 插件：
     - `app-id`：提取和验证 appId（优先级 1050）
     - `api-key`：验证 API Key（优先级 1000）
     - `billing`：扣减配额（优先级 900）
     - `cors`：跨域支持

2. **跳转路由** (`/s/*`)
   - 路径：`/s/*`
   - 方法：GET, HEAD
   - 认证：无需认证（公开接口）
   - 计费：无需计费（公开接口）
   - 插件：
     - `cors`：跨域支持

### Upstream 配置

- **名称**：`short-link-service`
- **类型**：`roundrobin`（轮询负载均衡）
- **节点**：`127.0.0.1:8110`（可配置）
- **健康检查**：启用主动和被动健康检查

## 测试

### 运行测试脚本

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-docker
./scripts/test-short-link-api.sh
```

### 环境变量配置（可选）

```bash
export APISIX_GATEWAY_URL=http://127.0.0.1:9080
export API_KEY=your-api-key
export APP_ID=your-app-id
export USER_ID=your-user-id

./scripts/test-short-link-api.sh
```

### 手动测试

#### 1. 创建短链接

```bash
curl -X POST "http://127.0.0.1:9080/v1/short-link?appId=your-app-id" \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "your-user-id",
    "appId": "your-app-id",
    "originalUrl": "https://example.com/test"
  }'
```

#### 2. 获取短链接列表

```bash
curl -X GET "http://127.0.0.1:9080/v1/short-links?appId=your-app-id&userId=your-user-id&page=1&pageSize=10" \
  -H "X-API-Key: your-api-key"
```

#### 3. 获取短链接信息

```bash
curl -X GET "http://127.0.0.1:9080/v1/short-link/abc123" \
  -H "X-API-Key: your-api-key"
```

#### 4. 测试短链接跳转（无需认证）

```bash
curl -X GET "http://127.0.0.1:9080/s/abc123" -L
```

#### 5. 获取统计信息

```bash
curl -X GET "http://127.0.0.1:9080/v1/short-link/abc123/stats?appId=your-app-id&startDate=2025-01-01&endDate=2025-01-31" \
  -H "X-API-Key: your-api-key"
```

## 验证配置

### 查看 Upstream

```bash
curl -X GET "http://127.0.0.1:9180/apisix/admin/upstreams/short-link-service" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" | jq
```

### 查看路由

```bash
# API 路由
curl -X GET "http://127.0.0.1:9180/apisix/admin/routes/short-link-service" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" | jq

# 跳转路由
curl -X GET "http://127.0.0.1:9180/apisix/admin/routes/short-link-redirect" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" | jq
```

## 删除配置

### 删除路由

```bash
# 删除 API 路由
curl -X DELETE "http://127.0.0.1:9180/apisix/admin/routes/short-link-service" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1"

# 删除跳转路由
curl -X DELETE "http://127.0.0.1:9180/apisix/admin/routes/short-link-redirect" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1"
```

### 删除 Upstream

```bash
curl -X DELETE "http://127.0.0.1:9180/apisix/admin/upstreams/short-link-service" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1"
```

## 故障排查

### 1. 无法连接到 APISIX Admin API

**问题**：脚本报错 "无法连接到 APISIX Admin API"

**解决方案**：
- 检查 APISIX 是否正在运行：`docker ps | grep apisix`
- 检查 APISIX_ADMIN_URL 是否正确（默认：`http://127.0.0.1:9180`）
- 检查防火墙设置

### 2. 路由创建失败

**问题**：路由创建返回错误

**解决方案**：
- 检查 APISIX_ADMIN_KEY 是否正确（默认：`edd1c9f034335f136f87ad84b625c8f1`）
- 检查 etcd 是否正常运行
- 查看 APISIX 日志：`docker logs apisix`

### 3. API 请求返回 401

**问题**：API 请求返回 401 Unauthorized

**解决方案**：
- 检查 API Key 是否正确
- 检查 `api-key` 插件配置是否正确
- 检查 api-key-service 是否正常运行

### 4. API 请求返回 402

**问题**：API 请求返回 402 Payment Required

**解决方案**：
- 检查用户配额是否充足
- 检查 `billing` 插件配置是否正确
- 检查 billing-service 是否正常运行

### 5. 短链接跳转失败

**问题**：访问 `/s/abc123` 返回 404

**解决方案**：
- 检查 short-link-service 是否正常运行
- 检查 upstream 配置是否正确
- 检查 short-link-service 的跳转路由是否正确配置

## 相关文档

- [APISIX 官方文档](https://apisix.apache.org/docs/)
- [Short Link Service README](../../short-link-service/README.md)
- [APISIX Plugin Runner README](../../apisix-devshare-plugin-runner/README.md)

