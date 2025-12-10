#!/bin/bash

# APISIX Docker 迁移到 Fork 仓库脚本
# 使用方法: ./migrate-to-fork.sh <your-fork-url>
# 例如: ./migrate-to-fork.sh git@github.com:your-org/apisix-docker.git

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查参数
if [ -z "$1" ]; then
    echo -e "${RED}错误: 请提供你的 Fork 仓库 URL${NC}"
    echo "使用方法: $0 <your-fork-url>"
    echo "例如: $0 git@github.com:your-org/apisix-docker.git"
    exit 1
fi

FORK_URL="$1"

echo -e "${GREEN}开始迁移到 Fork 仓库...${NC}"
echo ""

# 1. 检查当前状态
echo -e "${YELLOW}[1/6] 检查当前 Git 状态...${NC}"
if [ ! -d .git ]; then
    echo -e "${RED}错误: 当前目录不是 Git 仓库${NC}"
    exit 1
fi

CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
if [ -z "$CURRENT_REMOTE" ]; then
    echo -e "${RED}错误: 未找到 origin remote${NC}"
    exit 1
fi

echo "当前 origin: $CURRENT_REMOTE"
echo ""

# 2. 检查是否有未提交的修改
echo -e "${YELLOW}[2/6] 检查未提交的修改...${NC}"
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo -e "${YELLOW}发现未提交的修改，需要先提交${NC}"
    read -p "是否现在提交所有修改? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add .
        git commit -m "Add custom APISIX configuration and deployment files"
        echo -e "${GREEN}✓ 已提交所有修改${NC}"
    else
        echo -e "${YELLOW}跳过提交，请稍后手动提交${NC}"
    fi
else
    echo -e "${GREEN}✓ 工作区干净，无需提交${NC}"
fi
echo ""

# 3. 配置 upstream 和 origin
echo -e "${YELLOW}[3/6] 配置 Git remotes...${NC}"

# 将当前的 origin 改为 upstream
if git remote | grep -q "^upstream$"; then
    echo "upstream 已存在，更新中..."
    git remote set-url upstream "$CURRENT_REMOTE"
else
    echo "添加 upstream: $CURRENT_REMOTE"
    git remote rename origin upstream
fi

# 添加新的 origin（Fork 仓库）
if git remote | grep -q "^origin$"; then
    echo "origin 已存在，更新中..."
    git remote set-url origin "$FORK_URL"
else
    echo "添加 origin: $FORK_URL"
    git remote add origin "$FORK_URL"
fi

echo -e "${GREEN}✓ Remote 配置完成${NC}"
echo ""

# 4. 验证配置
echo -e "${YELLOW}[4/6] 验证 remote 配置...${NC}"
echo "当前 remotes:"
git remote -v
echo ""

# 5. 创建自定义分支
echo -e "${YELLOW}[5/6] 创建自定义分支...${NC}"
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "custom" ]; then
    if git branch | grep -q " custom$"; then
        echo "custom 分支已存在，切换到 custom 分支"
        git checkout custom
    else
        echo "创建 custom 分支（基于 $CURRENT_BRANCH）"
        git checkout -b custom
    fi
else
    echo "已在 custom 分支上"
fi
echo -e "${GREEN}✓ 分支配置完成${NC}"
echo ""

# 6. 提示下一步操作
echo -e "${YELLOW}[6/6] 迁移完成！${NC}"
echo ""
echo -e "${GREEN}下一步操作:${NC}"
echo ""
echo "1. 确保你的 Fork 仓库已创建:"
echo "   - 访问 https://github.com/apache/apisix-docker"
echo "   - 点击右上角 'Fork' 按钮"
echo "   - Fork 到你的账户"
echo ""
echo "2. 推送代码到你的 Fork 仓库:"
echo "   ${GREEN}git push -u origin custom${NC}"
echo ""
echo "3. 在 GitHub 上设置 custom 为默认分支:"
echo "   - Settings → Branches → Default branch → 选择 custom"
echo ""
echo "4. 验证配置:"
echo "   ${GREEN}git remote -v${NC}"
echo "   ${GREEN}git branch${NC}"
echo ""
echo -e "${GREEN}迁移完成！现在可以开始使用你的 Fork 仓库了。${NC}"
