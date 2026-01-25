#!/bin/bash

# Analytics Service API 测试脚本

set -e

# 配置变量
APISIX_GATEWAY_URL="${APISIX_GATEWAY_URL:-http://127.0.0.1:9080}"
API_KEY="${API_KEY:-dsh_devshareweb12345678901234567890}"
APP_ID="${APP_ID:-default-app}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 测试获取概览数据
test_get_overview() {
    log_info "测试获取概览数据..."
    
    local start_date=$(date -u -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-7d +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
    local end_date=$(date -u +%Y-%m-%d)
    
    local response=$(curl -s -w "\n%{http_code}" \
        -X GET "${APISIX_GATEWAY_URL}/analytics/v1/overview?appId=${APP_ID}&startDate=${start_date}&endDate=${end_date}" \
        -H "X-API-Key: ${API_KEY}")
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ]; then
        log_info "✓ 获取概览数据成功"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
    else
        log_error "✗ 获取概览数据失败: HTTP ${http_code}"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
        return 1
    fi
}

# 测试获取渠道分析
test_get_channels() {
    log_info "测试获取渠道分析..."
    
    local start_date=$(date -u -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-7d +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
    local end_date=$(date -u +%Y-%m-%d)
    
    local response=$(curl -s -w "\n%{http_code}" \
        -X GET "${APISIX_GATEWAY_URL}/analytics/v1/channels?appId=${APP_ID}&startDate=${start_date}&endDate=${end_date}&attributionModel=last_click" \
        -H "X-API-Key: ${API_KEY}")
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ]; then
        log_info "✓ 获取渠道分析成功"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
    else
        log_error "✗ 获取渠道分析失败: HTTP ${http_code}"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
        return 1
    fi
}

# 测试创建 UTM 链接
test_create_utm_link() {
    log_info "测试创建 UTM 链接..."
    
    local response=$(curl -s -w "\n%{http_code}" \
        -X POST "${APISIX_GATEWAY_URL}/analytics/v1/utm?appId=${APP_ID}" \
        -H "X-API-Key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{
            "originalUrl": "https://example.com/page",
            "utmSource": "test",
            "utmMedium": "email",
            "utmCampaign": "test-campaign",
            "name": "Test UTM Link"
        }')
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ] || [ "${http_code}" = "201" ]; then
        log_info "✓ 创建 UTM 链接成功"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
    else
        log_error "✗ 创建 UTM 链接失败: HTTP ${http_code}"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
        return 1
    fi
}

# 测试获取 UTM 链接列表
test_list_utm_links() {
    log_info "测试获取 UTM 链接列表..."
    
    local response=$(curl -s -w "\n%{http_code}" \
        -X GET "${APISIX_GATEWAY_URL}/analytics/v1/utm?appId=${APP_ID}&page=1&pageSize=10" \
        -H "X-API-Key: ${API_KEY}")
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ]; then
        log_info "✓ 获取 UTM 链接列表成功"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
    else
        log_error "✗ 获取 UTM 链接列表失败: HTTP ${http_code}"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
        return 1
    fi
}

# 测试获取智能建议
test_get_recommendations() {
    log_info "测试获取智能建议..."
    
    local start_date=$(date -u -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-7d +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
    local end_date=$(date -u +%Y-%m-%d)
    
    local response=$(curl -s -w "\n%{http_code}" \
        -X GET "${APISIX_GATEWAY_URL}/analytics/v1/recommendations?appId=${APP_ID}&startDate=${start_date}&endDate=${end_date}" \
        -H "X-API-Key: ${API_KEY}")
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ]; then
        log_info "✓ 获取智能建议成功"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
    else
        log_error "✗ 获取智能建议失败: HTTP ${http_code}"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
        return 1
    fi
}

# 主函数
main() {
    log_info "开始测试 Analytics Service API..."
    log_info "APISIX Gateway URL: ${APISIX_GATEWAY_URL}"
    log_info "API Key: ${API_KEY:0:20}..."
    log_info "App ID: ${APP_ID}"
    log_info ""
    
    # 运行测试
    test_get_overview || exit 1
    echo ""
    
    test_get_channels || exit 1
    echo ""
    
    test_create_utm_link || exit 1
    echo ""
    
    test_list_utm_links || exit 1
    echo ""
    
    test_get_recommendations || exit 1
    
    log_info ""
    log_info "所有测试通过！"
}

# 执行主函数
main "$@"

