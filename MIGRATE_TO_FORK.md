# 迁移到 Fork 仓库指南

## 当前状态

✅ 你已经从官方仓库 clone 了代码  
✅ 你已经修改了配置文件（`example/apisix_conf/config.yaml`）  
✅ 你需要管理这些自定义配置  

## 迁移步骤

### 1. Fork 官方仓库（在 GitHub/GitLab 上操作）

1. 访问：https://github.com/apache/apisix-docker
2. 点击右上角 "Fork" 按钮
3. Fork 到你的组织或个人账户：`https://github.com/your-org/apisix-docker`

### 2. 配置本地仓库

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-docker

# 查看当前 remote 配置
git remote -v
# 应该看到：
# origin  https://github.com/apache/apisix-docker.git

# 将官方仓库改为 upstream
git remote rename origin upstream

# 添加你自己的仓库为 origin
git remote add origin https://github.com/your-org/apisix-docker.git

# 验证配置
git remote -v
# 应该看到：
# origin    https://github.com/your-org/apisix-docker.git (fetch)
# origin    https://github.com/your-org/apisix-docker.git (push)
# upstream  https://github.com/apache/apisix-docker.git (fetch)
# upstream  https://github.com/apache/apisix-docker.git (push)
```

### 3. 提交当前的自定义配置

```bash
# 查看当前修改
git status

# 添加自定义配置文件
git add example/apisix_conf/config.yaml
git add example/docker-compose.simple.yml
git add docs/

# 提交修改
git commit -m "Add custom APISIX configuration and deployment files"

# 查看提交历史
git log --oneline -5
```

### 4. 创建自定义分支并推送

```bash
# 创建自定义分支（基于当前分支）
git checkout -b custom

# 或者如果你想基于官方最新代码
git fetch upstream
git checkout -b custom upstream/master

# 如果有未提交的修改，先提交
git add .
git commit -m "Add custom configuration"

# 推送到自己的仓库
git push -u origin custom

# 设置 custom 为默认分支（在 GitHub/GitLab 上操作）
# Settings → Branches → Default branch → 选择 custom
```

### 5. 验证迁移

```bash
# 查看当前分支
git branch

# 查看 remote 配置
git remote -v

# 查看提交历史
git log --oneline --graph --all -10

# 测试推送
git push origin custom
```

## 日常使用

### 修改配置

```bash
# 1. 修改配置文件
vim example/apisix_conf/config.yaml

# 2. 查看修改
git diff

# 3. 提交修改
git add example/apisix_conf/config.yaml
git commit -m "config: update Admin API key"

# 4. 推送到自己的仓库
git push origin custom
```

### 同步官方更新

```bash
# 1. 拉取官方更新
git fetch upstream

# 2. 查看更新内容
git log custom..upstream/master --oneline

# 3. 合并官方更新
git checkout custom
git merge upstream/master

# 4. 如果有冲突，解决冲突
# 编辑冲突文件，然后：
git add .
git commit -m "chore: sync upstream updates"

# 5. 推送更新
git push origin custom
```

## 配置文件管理

### 需要版本控制的文件

✅ **必须提交**：
- `example/apisix_conf/config.yaml` - APISIX 配置
- `example/docker-compose.simple.yml` - Docker Compose 配置
- `docs/` - 自定义文档

### 不需要版本控制的文件

❌ **添加到 .gitignore**：

```bash
# 编辑 .gitignore
cat >> .gitignore <<EOF

# 本地覆盖配置
example/apisix_conf/config.yaml.local
example/apisix_conf/config-*.local

# 环境变量
.env
.env.local
.env.*.local

# 敏感信息
**/secrets/
**/*.key
**/*.pem
!example/mkcert/*.pem  # 保留示例证书
EOF

# 提交 .gitignore
git add .gitignore
git commit -m "chore: update .gitignore for custom configs"
```

## 与主项目集成

### 方案 A: 保持独立（推荐）

保持 `apisix-docker` 为独立仓库，在主项目中通过路径引用：

```bash
# 在部署脚本中
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-docker/example
docker-compose -f docker-compose.simple.yml up -d
```

### 方案 B: Git Submodule

如果需要将 `apisix-docker` 作为主项目的子模块：

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech

# 如果 apisix-docker 已经是独立目录，先删除
# rm -rf apisix-docker

# 添加为子模块
git submodule add https://github.com/your-org/apisix-docker.git apisix-docker

# 使用
cd apisix-docker
git checkout custom
```

## 检查清单

### 迁移前

- [ ] Fork 官方仓库到自己的 GitHub/GitLab
- [ ] 备份当前修改（`git status` 查看）

### 迁移中

- [ ] 配置 upstream 和 origin
- [ ] 提交当前的自定义配置
- [ ] 创建自定义分支
- [ ] 推送到自己的仓库

### 迁移后

- [ ] 验证 remote 配置
- [ ] 测试推送和拉取
- [ ] 更新 .gitignore
- [ ] 建立同步流程

## 常见问题

### Q: 如果本地有未提交的修改怎么办？

```bash
# 查看未提交的修改
git status

# 提交所有修改
git add .
git commit -m "Save current changes before migration"

# 或者暂存修改
git stash
# 迁移后再恢复
git stash pop
```

### Q: 如何查看与官方的差异？

```bash
# 查看配置文件的差异
git diff upstream/master..custom -- example/apisix_conf/config.yaml

# 查看所有差异
git diff upstream/master..custom
```

### Q: 如何回退到官方版本？

```bash
# 回退单个文件
git checkout upstream/master -- example/apisix_conf/config.yaml
git commit -m "revert: restore official config"

# 或者创建新分支基于官方
git checkout -b official upstream/master
```

## 总结

✅ **你的理解完全正确！**

1. ✅ Fork 官方仓库 → 管理自定义配置
2. ✅ 配置 upstream → 方便同步官方更新
3. ✅ 创建自定义分支 → 独立管理自定义修改
4. ✅ 版本控制 → 所有配置修改都有历史记录

这样既保留了官方历史，又能管理自定义配置，还能方便地同步更新！
