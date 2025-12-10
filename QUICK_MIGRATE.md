# 快速迁移指南

## 当前状态

✅ 已从官方仓库 clone  
✅ 已修改配置文件  
✅ 需要迁移到自己的 Fork 仓库  

## 三步完成迁移

### 1. Fork 官方仓库（在 GitHub 上操作）

访问：https://github.com/apache/apisix-docker  
点击右上角 **"Fork"** 按钮  
Fork 到你的账户：`https://github.com/your-username/apisix-docker`

### 2. 运行迁移脚本

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-docker

# 使用 SSH URL（推荐）
./migrate-to-fork.sh git@github.com:your-username/apisix-docker.git

# 或使用 HTTPS URL
./migrate-to-fork.sh https://github.com/your-username/apisix-docker.git
```

### 3. 推送代码

```bash
# 提交当前修改（如果脚本提示）
git add .
git commit -m "Add custom APISIX configuration"

# 推送到你的 Fork 仓库
git push -u origin custom
```

## 完成！

现在你的配置已经版本控制，可以：
- ✅ 管理自定义配置
- ✅ 同步官方更新
- ✅ 团队协作

## 验证

```bash
# 查看 remote 配置
git remote -v
# 应该看到：
# origin    git@github.com:your-username/apisix-docker.git
# upstream  git@github.com:apache/apisix-docker.git

# 查看当前分支
git branch
# 应该看到：* custom
```

## 日常使用

### 修改配置

```bash
vim example/apisix_conf/config.yaml
git add example/apisix_conf/config.yaml
git commit -m "config: update Admin API key"
git push origin custom
```

### 同步官方更新

```bash
git fetch upstream
git merge upstream/master
git push origin custom
```

## 需要帮助？

查看详细文档：
- `MIGRATE_TO_FORK.md` - 详细迁移步骤
- `docs/GIT_STRATEGY.md` - Git 管理策略
- `docs/SETUP_GIT.md` - Git 设置指南
