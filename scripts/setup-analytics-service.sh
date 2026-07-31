#!/bin/bash

# ============================================================================
# Analytics Service APISIX 路由配置脚本（开发/本地环境）
#
# 功能:
#   1. 创建 analytics-upstream → analytics-service:8110
#   2. 创建 analytics-service Service，挂载 4 个 ext-plugin-pre-req 插件:
#      - app-id      (priority 1050) 提取 appId
#      - api-key     (priority 1000) 调 api-key-service 验证 X-API-Key
#      - jwt-user    (priority 950)  解析 JWT 提取用户
#      - billing     (priority 900)  扣减配额
#   3. 创建 2 条路由:
#      - analytics-track-route   /analytics/v1/track*    (写入侧, 限流 100 req/s/IP)
#      - analytics-query-route   /analytics/v1/*         (查询侧, 限流 20 req/s/IP)
#
# 设计差异:
#   - 写入接口 (track) 单 IP 100 RPS, 防止 SDK bug 或滥用打爆 DB
#   - 查询接口 (overview/channels/...) 单 IP 20 RPS, 防爬虫
#   - 两条路由都 enable api-key, 只是写入路由额外加 limit-req
#
# 与 infra-deploy/scripts/setup-apisix.sh 的关系:
#   - infra-deploy 是"生产环境一键配所有微服务"的脚本
#   - 本脚本是"只配 analytics-service 单服务"的精简版, 用于:
#     a) 本地开发快速重置
#     b) 灰度发版只想刷新 analytics-service 路由时
#   - 两边的路由配置必须保持兼容, 且必须由 analytics-service 团队维护
#
# 幂等性:
#   - 全部用 PUT 方法创建/更新, 重复执行结果一致
# ============================================================================

set -euo pipefail

APISIX_ADMIN_URL="${APISIX_ADMIN_URL:-http://127.0.0.1:9180}"
APISIX_ADMIN_KEY="${APISIX_ADMIN_KEY:-edd1c9f034335f136f87ad84b625c8f1}"
ANALYTICS_SERVICE_HOST="${ANALYTICS_SERVICE_HOST:-host.docker.internal}"
ANALYTICS_SERVICE_PORT="${ANALYTICS_SERVICE_PORT:-8110}"
API_KEY_SERVICE_ADDR="${API_KEY_SERVICE_ADDR:-api-key-service:9106}"
BILLING_SERVICE_ADDR="${BILLING_SERVICE_ADDR:-billing-service:9107}"
DEFAULT_APP_ID="${DEFAULT_APP_ID:-00000000-0000-0000-0000-000000000001}"
# 直连浏览器 SDK 的允许来源。不要使用 *，否则 credentials 请求会被浏览器拒绝。
ANALYTICS_ALLOWED_ORIGINS="${ANALYTICS_ALLOWED_ORIGINS:-https://web.homepagetab.com,https://www.homepagetab.com,https://www.zhijuanyun.com,https://www.getpopplan.com,https://www.paopaopaike.com,https://www.atseeker.com,http://localhost:3000,http://localhost:3001,http://localhost:3002,http://localhost:3003,http://localhost:3101,http://localhost:3102}"

# 写入侧限流: 单 IP 100 RPS, burst 50, 超出返回 429
TRACK_LIMIT_RATE="${TRACK_LIMIT_RATE:-100}"
TRACK_LIMIT_BURST="${TRACK_LIMIT_BURST:-50}"

# 查询侧限流: 单 IP 20 RPS, burst 10
QUERY_LIMIT_RATE="${QUERY_LIMIT_RATE:-20}"
QUERY_LIMIT_BURST="${QUERY_LIMIT_BURST:-10}"

# ----------------------------------------------------------------------------
# 颜色输出
# ----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ----------------------------------------------------------------------------
# 通用 PUT 请求函数
# ----------------------------------------------------------------------------
apisix_put() {
    local resource="$1"  # e.g. upstreams/analytics-upstream
    local body="$2"
    local desc="$3"

    local resp http_code
    resp=$(curl -sS -w "\n%{http_code}" -X PUT \
        "${APISIX_ADMIN_URL}/apisix/admin/${resource}" \
        -H "X-API-KEY: ${APISIX_ADMIN_KEY}" \
        -H "Content-Type: application/json" \
        -d "${body}")
    http_code=$(echo "${resp}" | tail -n1)
    local response_body
    response_body=$(echo "${resp}" | sed '$d')

    if [[ "${http_code}" == "200" || "${http_code}" == "201" ]]; then
        log_info "${desc} OK (HTTP ${http_code})"
    else
        log_error "${desc} FAILED (HTTP ${http_code})"
        echo "${response_body}" | python3 -m json.tool 2>/dev/null || echo "${response_body}"
        return 1
    fi
}

# ----------------------------------------------------------------------------
# 0. 健康检查
# ----------------------------------------------------------------------------
check_apisix_admin() {
    log_info "checking APISIX Admin API at ${APISIX_ADMIN_URL}"
    local code
    code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 5 \
        "${APISIX_ADMIN_URL}/apisix/admin/routes" \
        -H "X-API-KEY: ${APISIX_ADMIN_KEY}")
    if [[ "${code}" != "200" ]]; then
        log_error "APISIX Admin API not reachable (HTTP ${code})"
        log_error "  - check APISIX_ADMIN_URL=${APISIX_ADMIN_URL}"
        log_error "  - check APISIX_ADMIN_KEY (current prefix: ${APISIX_ADMIN_KEY:0:5}...)"
        exit 1
    fi
    log_info "APISIX Admin API reachable"
}

# ----------------------------------------------------------------------------
# 1. Upstream
# ----------------------------------------------------------------------------
create_upstream() {
    local body
    body=$(cat <<EOF
{
    "id": "analytics-upstream",
    "name": "analytics-service",
    "type": "roundrobin",
    "scheme": "http",
    "nodes": {
        "${ANALYTICS_SERVICE_HOST}:${ANALYTICS_SERVICE_PORT}": 1
    },
    "timeout": {
        "connect": 30,
        "send": 30,
        "read": 30
    },
    "checks": {
        "active": {
            "type": "http",
            "http_path": "/health",
            "healthy": {"interval": 5, "successes": 2},
            "unhealthy": {"interval": 5, "http_failures": 3}
        }
    }
}
EOF
)
    apisix_put "upstreams/analytics-upstream" "${body}" "upstream analytics-upstream"
}

# ----------------------------------------------------------------------------
# 2. Service - 挂载 ext-plugin-pre-req 插件链 (api-key/app-id/jwt-user/billing)
# ----------------------------------------------------------------------------
create_service() {
    local body
    body=$(cat <<EOF
{
    "id": "analytics-service",
    "name": "analytics-service",
    "upstream_id": "analytics-upstream",
    "plugins": {
        "cors": {
            "allow_origins": "${ANALYTICS_ALLOWED_ORIGINS}",
            "allow_methods": "GET,POST,OPTIONS",
            "allow_headers": "Content-Type,Authorization,X-API-Key,X-App-Id,X-Trace-Id",
            "expose_headers": "X-Trace-Id",
            "allow_credential": true,
            "max_age": 3600
        },
        "ext-plugin-pre-req": {
            "conf": [
                {
                    "name": "app-id",
                    "value": "{\"validate_app_id\":false,\"default_app_id\":\"${DEFAULT_APP_ID}\"}",
                    "_meta": {"priority": 1050}
                },
                {
                    "name": "api-key",
                    "value": "{\"address\":\"${API_KEY_SERVICE_ADDR}\",\"service_name\":\"analytics-service\"}",
                    "_meta": {"priority": 1000}
                },
                {
                    "name": "jwt-user",
                    "value": "{}",
                    "_meta": {"priority": 950}
                },
                {
                    "name": "billing",
                    "value": "{\"address\":\"${BILLING_SERVICE_ADDR}\"}",
                    "_meta": {"priority": 900}
                }
            ]
        }
    }
}
EOF
)
    apisix_put "services/analytics-service" "${body}" "service analytics-service"
}

# ----------------------------------------------------------------------------
# 3a. Track Route - 写入侧, 单 IP 100 RPS 限流
# ----------------------------------------------------------------------------
create_track_route() {
    local body
    body=$(cat <<EOF
{
    "id": "analytics-track-route",
    "name": "Analytics Track (write path)",
    "uri": "/analytics/v1/track*",
    "methods": ["POST", "OPTIONS"],
    "service_id": "analytics-service",
    "plugins": {
        "limit-req": {
            "rate": ${TRACK_LIMIT_RATE},
            "burst": ${TRACK_LIMIT_BURST},
            "key_type": "var",
            "key": "remote_addr",
            "rejected_code": 429,
            "rejected_msg": "Too many requests, slow down."
        }
    }
}
EOF
)
    apisix_put "routes/analytics-track-route" "${body}" "route /analytics/v1/track* (limit ${TRACK_LIMIT_RATE} rps/IP)"
}

# ----------------------------------------------------------------------------
# 3b. Query Route - 查询侧, 单 IP 20 RPS 限流
# ----------------------------------------------------------------------------
create_query_route() {
    local body
    body=$(cat <<EOF
{
    "id": "analytics-query-route",
    "name": "Analytics Query (read path)",
    "uri": "/analytics/v1/*",
    "methods": ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"],
    "service_id": "analytics-service",
    "priority": 0,
    "plugins": {
        "limit-req": {
            "rate": ${QUERY_LIMIT_RATE},
            "burst": ${QUERY_LIMIT_BURST},
            "key_type": "var",
            "key": "remote_addr",
            "rejected_code": 429,
            "rejected_msg": "Too many requests, slow down."
        }
    }
}
EOF
)
    apisix_put "routes/analytics-query-route" "${body}" "route /analytics/v1/* (limit ${QUERY_LIMIT_RATE} rps/IP)"
}

# ----------------------------------------------------------------------------
# main
# ----------------------------------------------------------------------------
main() {
    echo "========================================"
    echo "Analytics Service APISIX setup"
    echo "  APISIX Admin:    ${APISIX_ADMIN_URL}"
    echo "  Upstream target: ${ANALYTICS_SERVICE_HOST}:${ANALYTICS_SERVICE_PORT}"
    echo "  api-key svc:     ${API_KEY_SERVICE_ADDR}"
    echo "  billing svc:     ${BILLING_SERVICE_ADDR}"
    echo "  Track limit:     ${TRACK_LIMIT_RATE} rps/IP (burst ${TRACK_LIMIT_BURST})"
    echo "  Query limit:     ${QUERY_LIMIT_RATE} rps/IP (burst ${QUERY_LIMIT_BURST})"
    echo "========================================"

    check_apisix_admin
    create_upstream
    create_service
    # 注意: track 路由要比 query 路由优先匹配
    # APISIX 默认按路径精度匹配, /analytics/v1/track* 比 /analytics/v1/* 更精确, 自动优先
    create_track_route
    create_query_route

    echo "========================================"
    log_info "Analytics Service APISIX configuration done."
    echo
    log_info "Verify routes:"
    echo "  curl ${APISIX_ADMIN_URL}/apisix/admin/routes/analytics-track-route -H 'X-API-KEY: ${APISIX_ADMIN_KEY:0:5}...' | jq"
    echo "  curl ${APISIX_ADMIN_URL}/apisix/admin/routes/analytics-query-route -H 'X-API-KEY: ${APISIX_ADMIN_KEY:0:5}...' | jq"
    echo
    log_info "Test (replace API_KEY with a real key created via api-key-service):"
    echo "  curl -X POST 'http://127.0.0.1:9080/analytics/v1/track?appId=${DEFAULT_APP_ID}' \\"
    echo "    -H 'X-API-Key: dsh_xxx' \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"eventName\":\"page_view\",\"sessionId\":\"s1\",\"pageUrl\":\"https://example.com\"}'"
}

main "$@"
