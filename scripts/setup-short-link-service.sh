#!/bin/bash

# APISIX Gateway 路由配置脚本 - Short Link Service
# 用途：配置 short-link-service 的路由和上游服务

set -e

# 配置变量
APISIX_ADMIN_URL="${APISIX_ADMIN_URL:-http://127.0.0.1:9180}"
APISIX_ADMIN_KEY="${APISIX_ADMIN_KEY:-edd1c9f034335f136f87ad84b625c8f1}"
SHORT_LINK_SERVICE_HOST="${SHORT_LINK_SERVICE_HOST:-127.0.0.1}"
SHORT_LINK_SERVICE_PORT="${SHORT_LINK_SERVICE_PORT:-8110}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 APISIX Admin API 是否可用
check_apisix() {
    log_info "检查 APISIX Admin API 连接..."
    if ! curl -s -f "${APISIX_ADMIN_URL}/apisix/admin/routes" \
        -H "X-API-KEY: ${APISIX_ADMIN_KEY}" > /dev/null 2>&1; then
        log_error "无法连接到 APISIX Admin API: ${APISIX_ADMIN_URL}"
        log_error "请确保 APISIX 正在运行，并检查 APISIX_ADMIN_URL 和 APISIX_ADMIN_KEY 配置"
        exit 1
    fi
    log_info "APISIX Admin API 连接正常"
}

# 创建 upstream
create_upstream() {
    local upstream_id="short-link-service"
    log_info "创建 upstream: ${upstream_id}..."
    
    local upstream_config=$(cat <<EOF
{
  "id": "${upstream_id}",
  "name": "short-link-service",
  "type": "roundrobin",
  "nodes": {
    "${SHORT_LINK_SERVICE_HOST}:${SHORT_LINK_SERVICE_PORT}": 1
  },
  "scheme": "http",
  "timeout": {
    "connect": 6,
    "send": 6,
    "read": 6
  },
  "healthchecker": {
    "active": {
      "healthy": {
        "interval": 2,
        "http_statuses": [200, 201, 204],
        "successes": 1
      },
      "http_path": "/health",
      "unhealthy": {
        "interval": 1,
        "http_statuses": [429, 404, 500, 502, 503, 504],
        "timeouts": 3,
        "tcp_failures": 3,
        "http_failures": 2,
        "continuous_failures": 3
      },
      "req_headers": ["User-Agent: APISIX-Health-Check"],
      "timeout": 1
    },
    "passive": {
      "healthy": {
        "http_statuses": [200, 201, 204, 302],
        "successes": 3
      },
      "unhealthy": {
        "http_statuses": [429, 500, 503],
        "tcp_failures": 3,
        "timeouts": 3,
        "http_failures": 3,
        "continuous_failures": 3
      }
    }
  }
}
EOF
)

    local response=$(curl -s -w "\n%{http_code}" \
        -X PUT "${APISIX_ADMIN_URL}/apisix/admin/upstreams/${upstream_id}" \
        -H "X-API-KEY: ${APISIX_ADMIN_KEY}" \
        -H "Content-Type: application/json" \
        -d "${upstream_config}")
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ] || [ "${http_code}" = "201" ]; then
        log_info "Upstream 创建成功: ${upstream_id}"
        echo "${body}" | jq -r '.value.nodes' 2>/dev/null || echo ""
    else
        log_error "Upstream 创建失败: HTTP ${http_code}"
        echo "${body}" | jq -r '.error_msg // .message // .' 2>/dev/null || echo "${body}"
        exit 1
    fi
}

# 创建路由
create_route() {
    local route_id="short-link-service"
    log_info "创建路由: ${route_id}..."
    
    local route_config=$(cat <<EOF
{
  "id": "${route_id}",
  "name": "short-link-service",
  "uri": "/v1/short-link*",
  "methods": ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"],
  "upstream_id": "short-link-service",
  "plugins": {
    "ext-plugin-pre-req": {
      "conf": [
        {
          "name": "app-id",
          "value": "{\"validate_app_id\":true,\"cache_ttl\":300}",
          "_meta": {
            "priority": 1050
          }
        },
        {
          "name": "api-key",
          "value": "{\"address\":\"host.docker.internal:9106\",\"public_routes\":[]}",
          "_meta": {
            "priority": 1000
          }
        },
        {
          "name": "billing",
          "value": "{\"address\":\"host.docker.internal:9107\",\"service_name\":\"short-link\",\"public_routes\":[]}",
          "_meta": {
            "priority": 900
          }
        }
      ]
    },
    "cors": {
      "allow_origins": "*",
      "allow_methods": ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"],
      "allow_headers": ["*"],
      "expose_headers": ["*"],
      "max_age": 3600
    }
  }
}
EOF
)

    local response=$(curl -s -w "\n%{http_code}" \
        -X PUT "${APISIX_ADMIN_URL}/apisix/admin/routes/${route_id}" \
        -H "X-API-KEY: ${APISIX_ADMIN_KEY}" \
        -H "Content-Type: application/json" \
        -d "${route_config}")
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ] || [ "${http_code}" = "201" ]; then
        log_info "路由创建成功: ${route_id}"
        echo "${body}" | jq -r '.value.uri' 2>/dev/null || echo ""
    else
        log_error "路由创建失败: HTTP ${http_code}"
        echo "${body}" | jq -r '.error_msg // .message // .' 2>/dev/null || echo "${body}"
        exit 1
    fi
}

# 创建短链接分组路由（需要匹配 /v1/short-link-groups）
create_groups_route() {
    local route_id="short-link-groups"
    log_info "创建分组路由: ${route_id}..."
    
    local route_config=$(cat <<EOF
{
  "id": "${route_id}",
  "name": "short-link-groups",
  "uri": "/v1/short-link-groups*",
  "methods": ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"],
  "upstream_id": "short-link-service",
  "plugins": {
    "ext-plugin-pre-req": {
      "conf": [
        {
          "name": "app-id",
          "value": "{\"validate_app_id\":true,\"cache_ttl\":300}",
          "_meta": {
            "priority": 1050
          }
        },
        {
          "name": "api-key",
          "value": "{\"address\":\"host.docker.internal:9106\",\"public_routes\":[]}",
          "_meta": {
            "priority": 1000
          }
        },
        {
          "name": "billing",
          "value": "{\"address\":\"host.docker.internal:9107\",\"service_name\":\"short-link\",\"public_routes\":[]}",
          "_meta": {
            "priority": 900
          }
        }
      ]
    },
    "cors": {
      "allow_origins": "*",
      "allow_methods": ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"],
      "allow_headers": ["*"],
      "expose_headers": ["*"],
      "max_age": 3600
    }
  }
}
EOF
)

    local response=$(curl -s -w "\n%{http_code}" \
        -X PUT "${APISIX_ADMIN_URL}/apisix/admin/routes/${route_id}" \
        -H "X-API-KEY: ${APISIX_ADMIN_KEY}" \
        -H "Content-Type: application/json" \
        -d "${route_config}")
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ] || [ "${http_code}" = "201" ]; then
        log_info "分组路由创建成功: ${route_id}"
        echo "${body}" | jq -r '.value.uri' 2>/dev/null || echo ""
    else
        log_error "分组路由创建失败: HTTP ${http_code}"
        echo "${body}" | jq -r '.error_msg // .message // .' 2>/dev/null || echo "${body}"
        exit 1
    fi
}

# 创建短链接列表路由（需要匹配 /v1/short-links）
create_links_route() {
    local route_id="short-link-links"
    log_info "创建列表路由: ${route_id}..."
    
    local route_config=$(cat <<EOF
{
  "id": "${route_id}",
  "name": "short-link-links",
  "uri": "/v1/short-links*",
  "methods": ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"],
  "upstream_id": "short-link-service",
  "plugins": {
    "ext-plugin-pre-req": {
      "conf": [
        {
          "name": "app-id",
          "value": "{\"validate_app_id\":true,\"cache_ttl\":300}",
          "_meta": {
            "priority": 1050
          }
        },
        {
          "name": "api-key",
          "value": "{\"address\":\"host.docker.internal:9106\",\"public_routes\":[]}",
          "_meta": {
            "priority": 1000
          }
        },
        {
          "name": "billing",
          "value": "{\"address\":\"host.docker.internal:9107\",\"service_name\":\"short-link\",\"public_routes\":[]}",
          "_meta": {
            "priority": 900
          }
        }
      ]
    },
    "cors": {
      "allow_origins": "*",
      "allow_methods": ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"],
      "allow_headers": ["*"],
      "expose_headers": ["*"],
      "max_age": 3600
    }
  }
}
EOF
)

    local response=$(curl -s -w "\n%{http_code}" \
        -X PUT "${APISIX_ADMIN_URL}/apisix/admin/routes/${route_id}" \
        -H "X-API-KEY: ${APISIX_ADMIN_KEY}" \
        -H "Content-Type: application/json" \
        -d "${route_config}")
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ] || [ "${http_code}" = "201" ]; then
        log_info "列表路由创建成功: ${route_id}"
        echo "${body}" | jq -r '.value.uri' 2>/dev/null || echo ""
    else
        log_error "列表路由创建失败: HTTP ${http_code}"
        echo "${body}" | jq -r '.error_msg // .message // .' 2>/dev/null || echo "${body}"
        exit 1
    fi
}

# 创建短链接跳转路由（不需要认证）
create_redirect_route() {
    local route_id="short-link-redirect"
    log_info "创建短链接跳转路由: ${route_id}..."
    
    # 短链接跳转路由不需要认证，直接转发
    local route_config=$(cat <<EOF
{
  "id": "${route_id}",
  "name": "short-link-redirect",
  "uri": "/s/*",
  "methods": ["GET", "HEAD"],
  "upstream_id": "short-link-service",
  "plugins": {
    "cors": {
      "allow_origins": "*",
      "allow_methods": ["GET", "HEAD"],
      "allow_headers": ["*"],
      "expose_headers": ["*"],
      "max_age": 3600
    }
  }
}
EOF
)

    local response=$(curl -s -w "\n%{http_code}" \
        -X PUT "${APISIX_ADMIN_URL}/apisix/admin/routes/${route_id}" \
        -H "X-API-KEY: ${APISIX_ADMIN_KEY}" \
        -H "Content-Type: application/json" \
        -d "${route_config}")
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ] || [ "${http_code}" = "201" ]; then
        log_info "跳转路由创建成功: ${route_id}"
        echo "${body}" | jq -r '.value.uri' 2>/dev/null || echo ""
    else
        log_error "跳转路由创建失败: HTTP ${http_code}"
        echo "${body}" | jq -r '.error_msg // .message // .' 2>/dev/null || echo "${body}"
        exit 1
    fi
}

# 验证配置
verify_config() {
    log_info "验证配置..."
    
    # 检查 upstream
    local upstream_response=$(curl -s -w "\n%{http_code}" \
        "${APISIX_ADMIN_URL}/apisix/admin/upstreams/short-link-service" \
        -H "X-API-KEY: ${APISIX_ADMIN_KEY}")
    local upstream_http_code=$(echo "${upstream_response}" | tail -n1)
    
    if [ "${upstream_http_code}" = "200" ]; then
        log_info "✓ Upstream 配置验证成功"
    else
        log_warn "✗ Upstream 配置验证失败"
    fi
    
    # 检查路由
    local route_response=$(curl -s -w "\n%{http_code}" \
        "${APISIX_ADMIN_URL}/apisix/admin/routes/short-link-service" \
        -H "X-API-KEY: ${APISIX_ADMIN_KEY}")
    local route_http_code=$(echo "${route_response}" | tail -n1)
    
    if [ "${route_http_code}" = "200" ]; then
        log_info "✓ 路由配置验证成功"
    else
        log_warn "✗ 路由配置验证失败"
    fi
    
    # 检查分组路由
    local groups_response=$(curl -s -w "\n%{http_code}" \
        "${APISIX_ADMIN_URL}/apisix/admin/routes/short-link-groups" \
        -H "X-API-KEY: ${APISIX_ADMIN_KEY}")
    local groups_http_code=$(echo "${groups_response}" | tail -n1)
    
    if [ "${groups_http_code}" = "200" ]; then
        log_info "✓ 分组路由配置验证成功"
    else
        log_warn "✗ 分组路由配置验证失败"
    fi
    
    # 检查列表路由
    local links_response=$(curl -s -w "\n%{http_code}" \
        "${APISIX_ADMIN_URL}/apisix/admin/routes/short-link-links" \
        -H "X-API-KEY: ${APISIX_ADMIN_KEY}")
    local links_http_code=$(echo "${links_response}" | tail -n1)
    
    if [ "${links_http_code}" = "200" ]; then
        log_info "✓ 列表路由配置验证成功"
    else
        log_warn "✗ 列表路由配置验证失败"
    fi
    
    # 检查跳转路由
    local redirect_response=$(curl -s -w "\n%{http_code}" \
        "${APISIX_ADMIN_URL}/apisix/admin/routes/short-link-redirect" \
        -H "X-API-KEY: ${APISIX_ADMIN_KEY}")
    local redirect_http_code=$(echo "${redirect_response}" | tail -n1)
    
    if [ "${redirect_http_code}" = "200" ]; then
        log_info "✓ 跳转路由配置验证成功"
    else
        log_warn "✗ 跳转路由配置验证失败"
    fi
}

# 主函数
main() {
    log_info "开始配置 Short Link Service 路由..."
    log_info "APISIX Admin URL: ${APISIX_ADMIN_URL}"
    log_info "Short Link Service: ${SHORT_LINK_SERVICE_HOST}:${SHORT_LINK_SERVICE_PORT}"
    
    check_apisix
    create_upstream
    create_route
    create_groups_route
    create_links_route
    create_redirect_route
    verify_config
    
    log_info "配置完成！"
    log_info ""
    log_info "路由信息："
    log_info "  - API 路由: /v1/short-link* (需要认证)"
    log_info "  - 分组路由: /v1/short-link-groups* (需要认证)"
    log_info "  - 列表路由: /v1/short-links* (需要认证)"
    log_info "  - 跳转路由: /s/* (无需认证)"
    log_info "  - 上游服务: ${SHORT_LINK_SERVICE_HOST}:${SHORT_LINK_SERVICE_PORT}"
    log_info ""
    log_info "测试命令："
    log_info "  curl -X GET '${APISIX_ADMIN_URL%:*}:9080/v1/short-link/abc123' -H 'X-API-Key: your-api-key'"
    log_info "  curl -X GET '${APISIX_ADMIN_URL%:*}:9080/s/abc123'"
}

# 执行主函数
main "$@"

