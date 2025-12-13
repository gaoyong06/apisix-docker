#!/bin/bash

# Short Link Service API 测试脚本

set -e

# 配置变量
APISIX_GATEWAY_URL="${APISIX_GATEWAY_URL:-http://127.0.0.1:9080}"
API_KEY="${API_KEY:-dsh_devshareweb12345678901234567890}"
APP_ID="${APP_ID:-default-app}"
USER_ID="${USER_ID:-default-user}"

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

# 测试创建短链接
test_create_short_link() {
    log_info "测试创建短链接..."
    
    local response=$(curl -s -w "\n%{http_code}" \
        -X POST "${APISIX_GATEWAY_URL}/v1/short-link?appId=${APP_ID}" \
        -H "X-API-Key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"userId\": \"${USER_ID}\",
            \"appId\": \"${APP_ID}\",
            \"originalUrl\": \"https://example.com/test?utm_source=test\"
        }")
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ] || [ "${http_code}" = "201" ]; then
        log_info "✓ 创建短链接成功"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
        # 提取 short_code
        local short_code=$(echo "${body}" | jq -r '.data.shortCode // .shortCode // empty' 2>/dev/null)
        if [ -n "${short_code}" ]; then
            echo "${short_code}" > /tmp/short_code.txt
            log_info "短码已保存: ${short_code}"
        fi
    else
        log_error "✗ 创建短链接失败: HTTP ${http_code}"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
        return 1
    fi
}

# 测试获取短链接列表
test_list_short_links() {
    log_info "测试获取短链接列表..."
    
    local response=$(curl -s -w "\n%{http_code}" \
        -X GET "${APISIX_GATEWAY_URL}/v1/short-links?appId=${APP_ID}&userId=${USER_ID}&page=1&pageSize=10" \
        -H "X-API-Key: ${API_KEY}")
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ]; then
        log_info "✓ 获取短链接列表成功"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
    else
        log_error "✗ 获取短链接列表失败: HTTP ${http_code}"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
        return 1
    fi
}

# 测试获取短链接信息
test_get_short_link() {
    local short_code="${1}"
    if [ -z "${short_code}" ]; then
        if [ -f /tmp/short_code.txt ]; then
            short_code=$(cat /tmp/short_code.txt)
        else
            log_warn "未提供 short_code，跳过测试"
            return 0
        fi
    fi
    
    log_info "测试获取短链接信息: ${short_code}..."
    
    local response=$(curl -s -w "\n%{http_code}" \
        -X GET "${APISIX_GATEWAY_URL}/v1/short-link/${short_code}" \
        -H "X-API-Key: ${API_KEY}")
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ]; then
        log_info "✓ 获取短链接信息成功"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
    else
        log_error "✗ 获取短链接信息失败: HTTP ${http_code}"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
        return 1
    fi
}

# 测试短链接跳转
test_redirect() {
    local short_code="${1}"
    if [ -z "${short_code}" ]; then
        if [ -f /tmp/short_code.txt ]; then
            short_code=$(cat /tmp/short_code.txt)
        else
            log_warn "未提供 short_code，跳过测试"
            return 0
        fi
    fi
    
    log_info "测试短链接跳转: /s/${short_code}..."
    
    local response=$(curl -s -w "\n%{http_code}" \
        -X GET "${APISIX_GATEWAY_URL}/s/${short_code}" \
        -L -o /dev/null)
    
    local http_code=$(echo "${response}" | tail -n1)
    
    if [ "${http_code}" = "200" ] || [ "${http_code}" = "302" ] || [ "${http_code}" = "301" ]; then
        log_info "✓ 短链接跳转成功: HTTP ${http_code}"
    else
        log_error "✗ 短链接跳转失败: HTTP ${http_code}"
        return 1
    fi
}

# 测试获取统计信息
test_get_stats() {
    local short_code="${1}"
    if [ -z "${short_code}" ]; then
        if [ -f /tmp/short_code.txt ]; then
            short_code=$(cat /tmp/short_code.txt)
        else
            log_warn "未提供 short_code，跳过测试"
            return 0
        fi
    fi
    
    log_info "测试获取统计信息: ${short_code}..."
    
    local start_date=$(date -u -d '7 days ago' +%Y-%m-%d 2>/dev/null || date -u -v-7d +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
    local end_date=$(date -u +%Y-%m-%d)
    
    local response=$(curl -s -w "\n%{http_code}" \
        -X GET "${APISIX_GATEWAY_URL}/v1/short-link/${short_code}/stats?appId=${APP_ID}&startDate=${start_date}&endDate=${end_date}" \
        -H "X-API-Key: ${API_KEY}")
    
    local http_code=$(echo "${response}" | tail -n1)
    local body=$(echo "${response}" | sed '$d')
    
    if [ "${http_code}" = "200" ]; then
        log_info "✓ 获取统计信息成功"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
    else
        log_error "✗ 获取统计信息失败: HTTP ${http_code}"
        echo "${body}" | jq '.' 2>/dev/null || echo "${body}"
        return 1
    fi
}

# 主函数
main() {
    log_info "开始测试 Short Link Service API..."
    log_info "APISIX Gateway URL: ${APISIX_GATEWAY_URL}"
    log_info "API Key: ${API_KEY:0:20}..."
    log_info "App ID: ${APP_ID}"
    log_info ""
    
    # 运行测试
    test_create_short_link || exit 1
    echo ""
    
    test_list_short_links || exit 1
    echo ""
    
    if [ -f /tmp/short_code.txt ]; then
        local short_code=$(cat /tmp/short_code.txt)
        test_get_short_link "${short_code}" || exit 1
        echo ""
        
        test_redirect "${short_code}" || exit 1
        echo ""
        
        test_get_stats "${short_code}" || exit 1
    fi
    
    log_info ""
    log_info "所有测试通过！"
}

# 执行主函数
main "$@"

