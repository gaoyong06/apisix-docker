# Analytics Service APISIX 路由配置指南

## 概述

本文档说明如何配置 APISIX Gateway 以支持 analytics-service。

## 前置条件

1. APISIX Gateway 已启动并运行
2. analytics-service 已启动并运行（默认端口：8109）
3. etcd 已启动并运行（APISIX 配置存储）
4. 已安装 `curl` 和 `jq` 工具

## 快速配置

### 1. 运行配置脚本

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-docker
./scripts/setup-analytics-service.sh
```

### 2. 环境变量配置（可选）

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `APISIX_ADMIN_URL` | `http://127.0.0.1:9180` | APISIX Admin API 地址 |
| `APISIX_ADMIN_KEY` | `edd1c9f034335f136f87ad84b625c8f1` | APISIX Admin Key |
| `ANALYTICS_SERVICE_HOST` | `host.docker.internal` | 上游 host（Docker 环境用 host.docker.internal，Linux 直连用 127.0.0.1 或 容器名） |
| `ANALYTICS_SERVICE_PORT` | `8110` | 上游 HTTP 端口 |
| `API_KEY_SERVICE_ADDR` | `api-key-service:9106` | api-key-service gRPC 地址 |
| `BILLING_SERVICE_ADDR` | `billing-service:9107` | billing-service gRPC 地址 |
| `DEFAULT_APP_ID` | `00000000-0000-0000-0000-000000000001` | app-id 插件兜底 appId |
| `ANALYTICS_ALLOWED_ORIGINS` | `https://web.homepagetab.com,...` | 浏览器 SDK 允许的 Origin 白名单；逗号分隔，不能使用 `*` |
| `TRACK_LIMIT_RATE` / `TRACK_LIMIT_BURST` | `100` / `50` | 写入路由单 IP RPS / 突发额度 |
| `QUERY_LIMIT_RATE` / `QUERY_LIMIT_BURST` | `20` / `10` | 查询路由单 IP RPS / 突发额度 |

```bash
ANALYTICS_SERVICE_HOST=127.0.0.1 \
ANALYTICS_SERVICE_PORT=8110 \
TRACK_LIMIT_RATE=200 \
./scripts/setup-analytics-service.sh
```

## 配置说明

### 路由配置

脚本会创建 **2 条路由**（写入路径单独限流，避免 SDK 异常或滥用打爆 DB）：

1. **写入路由 `/analytics/v1/track*`**（POST/OPTIONS）
   - 限流：单 IP **100 RPS**（burst 50），超出返回 429
   - 通过 Service `analytics-service` 继承下面的插件链
2. **查询路由 `/analytics/v1/*`**（GET/POST/PUT/DELETE/PATCH/HEAD/OPTIONS）
   - 限流：单 IP **20 RPS**（burst 10）
   - 通过 Service 继承同样的插件链

两条路由都挂在同一个 Service `analytics-service` 上，Service 上的插件链：
- `cors`：跨域支持
- `ext-plugin-pre-req`：
  - `app-id`：提取和验证 appId（优先级 1050）
  - `api-key`：验证 API Key（优先级 1000，调用 `api-key-service`）
  - `jwt-user`：解析 JWT 提取登录用户（优先级 950）
  - `billing`：扣减配额（优先级 900，调用 `billing-service`）

> 路径精度：`/analytics/v1/track*` 比 `/analytics/v1/*` 更精确，APISIX 会优先匹配；不需要手动设 `priority`。

### Upstream 配置

- **名称**：`analytics-service`
- **类型**：`roundrobin`（轮询负载均衡）
- **节点**：`127.0.0.1:8109`（可配置）
- **健康检查**：启用主动和被动健康检查

## API 端点

### 事件追踪
- `POST /analytics/v1/track` - 追踪事件
- `POST /analytics/v1/track/batch` - 批量追踪事件

### UTM 管理
- `POST /analytics/v1/utm` - 创建 UTM 链接
- `GET /analytics/v1/utm` - 获取 UTM 链接列表

### UTM 模板管理
- `POST /analytics/v1/utm/templates` - 创建 UTM 模板
- `PUT /analytics/v1/utm/templates/{template_id}` - 更新 UTM 模板
- `DELETE /analytics/v1/utm/templates/{template_id}` - 删除 UTM 模板
- `GET /analytics/v1/utm/templates` - 获取 UTM 模板列表
- `GET /analytics/v1/utm/templates/{template_id}` - 获取 UTM 模板详情

### 数据分析
- `GET /analytics/v1/overview` - 获取概览数据
- `GET /analytics/v1/channels` - 获取渠道分析
- `GET /analytics/v1/events` - 获取事件列表
- `GET /analytics/v1/funnel` - 漏斗分析
- `GET /analytics/v1/retention` - 留存分析
- `GET /analytics/v1/users` - 用户分析
- `GET /analytics/v1/users/path` - 用户路径分析

### Phase 3 功能
- `GET /analytics/v1/recommendations` - 获取智能建议
- `POST /analytics/v1/reports/generate` - 生成报表
- `GET /analytics/v1/export` - 导出数据

## 测试

### 运行测试脚本

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-docker
./scripts/test-analytics-api.sh
```

### 环境变量配置（可选）

```bash
export APISIX_GATEWAY_URL=http://127.0.0.1:9080
export API_KEY=your-api-key
export APP_ID=your-app-id

./scripts/test-analytics-api.sh
```

### 手动测试

#### 1. 获取概览数据

```bash
curl -X GET "http://127.0.0.1:9080/analytics/v1/overview?appId=your-app-id&startDate=2025-01-01&endDate=2025-01-31" \
  -H "X-API-Key: your-api-key"
```

#### 2. 获取渠道分析

```bash
curl -X GET "http://127.0.0.1:9080/analytics/v1/channels?appId=your-app-id&startDate=2025-01-01&endDate=2025-01-31&attributionModel=last_click" \
  -H "X-API-Key: your-api-key"
```

#### 3. 创建 UTM 链接

```bash
curl -X POST "http://127.0.0.1:9080/analytics/v1/utm?appId=your-app-id" \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "originalUrl": "https://example.com/page",
    "utmSource": "test",
    "utmMedium": "email",
    "utmCampaign": "test-campaign",
    "name": "Test UTM Link"
  }'
```

#### 4. 追踪事件

```bash
curl -X POST "http://127.0.0.1:9080/analytics/v1/track?appId=your-app-id" \
  -H "X-API-Key: your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "eventName": "page_view",
    "sessionId": "session-123",
    "pageUrl": "https://example.com/page",
    "pageTitle": "Example Page"
  }'
```

#### 5. 获取智能建议

```bash
curl -X GET "http://127.0.0.1:9080/analytics/v1/recommendations?appId=your-app-id&startDate=2025-01-01&endDate=2025-01-31" \
  -H "X-API-Key: your-api-key"
```

## 验证配置

### 查看 Upstream

```bash
curl -X GET "http://127.0.0.1:9180/apisix/admin/upstreams/analytics-service" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" | jq
```

### 查看路由

```bash
curl -X GET "http://127.0.0.1:9180/apisix/admin/routes/analytics-service" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" | jq
```

## 删除配置

### 删除路由

```bash
curl -X DELETE "http://127.0.0.1:9180/apisix/admin/routes/analytics-service" \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1"
```

### 删除 Upstream

```bash
curl -X DELETE "http://127.0.0.1:9180/apisix/admin/upstreams/analytics-service" \
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

### 5. 服务连接失败

**问题**：请求返回 502 Bad Gateway 或 503 Service Unavailable

**解决方案**：
- 检查 analytics-service 是否正常运行（端口 8109）
- 检查 upstream 配置中的主机和端口是否正确
- 检查 analytics-service 的健康检查端点是否正常

## 相关文档

- [APISIX 官方文档](https://apisix.apache.org/docs/)
- [Analytics Service README](../../analytics-service/README.md)
- [APISIX Plugin Runner README](../../apisix-devshare-plugin-runner/README.md)
