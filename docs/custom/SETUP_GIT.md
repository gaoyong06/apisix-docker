# APISIX Docker Git 设置指南

## 快速设置

### 1. Fork 官方仓库

在 GitHub/GitLab 上 Fork：
- 官方仓库：https://github.com/apache/apisix-docker
- Fork 到：`https://github.com/your-org/apisix-docker`

### 2. 配置本地仓库

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-docker

# 如果当前没有 git，先初始化
if [ ! -d .git ]; then
    git init
    git add .
    git commit -m "Initial commit: Custom APISIX configuration"
fi

# 添加自己的仓库为 origin
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/your-org/apisix-docker.git

# 添加官方仓库为 upstream
git remote remove upstream 2>/dev/null || true
git remote add upstream https://github.com/apache/apisix-docker.git

# 验证配置
git remote -v
```

### 3. 拉取官方代码并创建自定义分支

```bash
# 拉取官方代码
git fetch upstream

# 创建自定义分支（基于官方 main）
git checkout -b custom upstream/main

# 如果本地有修改，先提交
git add example/apisix_conf/config.yaml
git commit -m "Add custom APISIX configuration"

# 推送到自己的仓库
git push -u origin custom
```

### 4. 设置主分支

```bash
# 将 custom 分支设置为默认分支
git checkout custom
git branch -M custom
git push -u origin custom
```

## 日常使用

### 修改配置

```bash
# 1. 修改配置文件
vim example/apisix_conf/config.yaml

# 2. 提交修改
git add example/apisix_conf/config.yaml
git commit -m "config: update Admin API key"

# 3. 推送到自己的仓库
git push origin custom
```

### 同步官方更新

```bash
# 1. 拉取官方更新
git fetch upstream

# 2. 查看更新内容
git log custom..upstream/main --oneline

# 3. 合并官方更新
git checkout custom
git merge upstream/main

# 4. 解决冲突（如果有）
# 编辑冲突文件，然后：
git add .
git commit -m "chore: sync upstream updates"

# 5. 推送更新
git push origin custom
```

## 验证配置

```bash
# 查看远程仓库配置
git remote -v

# 应该看到：
# origin    https://github.com/your-org/apisix-docker.git (fetch)
# origin    https://github.com/your-org/apisix-docker.git (push)
# upstream  https://github.com/apache/apisix-docker.git (fetch)
# upstream  https://github.com/apache/apisix-docker.git (push)

# 查看当前分支
git branch

# 查看提交历史
git log --oneline --graph --all -10
```

## 常见问题

### Q: 如何查看本地修改了哪些文件？

```bash
git status
git diff
```

### Q: 如何查看与官方的差异？

```bash
git diff upstream/main..custom
```

### Q: 如何回退到官方版本？

```bash
git checkout upstream/main -- example/apisix_conf/config.yaml
git commit -m "revert: restore official config"
```

### Q: 如何创建功能分支？

```bash
git checkout -b feature/update-config
# 修改配置
git commit -m "feature: update config"
git push origin feature/update-config
```

## 下一步

1. ✅ Fork 官方仓库
2. ✅ 配置本地仓库
3. ✅ 创建自定义分支
4. ✅ 提交自定义配置
5. ✅ 推送到自己的仓库

完成！现在你的配置修改都可以版本控制了。
