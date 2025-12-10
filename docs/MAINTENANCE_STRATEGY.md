# APISIX Docker 项目维护策略

## 问题分析

### 当前状况

1. **apisix-docker**: 从官方仓库 `https://github.com/apache/apisix-docker.git` clone 的配置项目
2. **apisix-devshare-plugin-runner**: 自定义 Go 插件项目
3. **自定义配置**: 在 `apisix-docker/example/apisix_conf/config.yaml` 中修改了配置

### 核心问题

1. **是否需要维护 apisix-docker？**
2. **生产环境如何发布？**
3. **项目结构如何组织？**
4. **如何与官方仓库同步？**

## 行业最佳实践分析

### 1. Fork vs 独立维护

#### 方案 A: Fork 官方仓库（推荐用于少量自定义）

**优点**：
- ✅ 可以轻松同步官方更新
- ✅ 保持与官方版本兼容
- ✅ 便于贡献回官方

**缺点**：
- ⚠️ 如果自定义配置过多，merge 冲突会频繁
- ⚠️ 需要维护 fork 关系

**适用场景**：
- 自定义配置较少（< 20%）
- 需要频繁同步官方更新
- 希望贡献代码回官方

#### 方案 B: 独立维护（推荐用于大量自定义）

**优点**：
- ✅ 完全控制配置和结构
- ✅ 不受官方变更影响
- ✅ 可以自由组织项目结构

**缺点**：
- ⚠️ 需要手动同步官方更新
- ⚠️ 可能错过官方新特性

**适用场景**：
- 自定义配置较多（> 20%）
- 有独特的部署需求
- 不需要频繁同步官方更新

#### 方案 C: Git Subtree（推荐用于混合场景）

**优点**：
- ✅ 可以独立维护，同时保留官方历史
- ✅ 可以选择性同步官方更新
- ✅ 项目结构清晰

**缺点**：
- ⚠️ 操作相对复杂
- ⚠️ 需要理解 subtree 概念

**适用场景**：
- 需要保留官方历史
- 需要选择性同步更新
- 团队熟悉 Git 高级操作

### 2. 项目结构组织

#### 方案 A: 分离维护（推荐）

```
xinyuan_tech/
├── apisix-docker/          # APISIX 配置和 Docker Compose
│   ├── example/
│   │   └── apisix_conf/
│   │       └── config.yaml  # 自定义配置
│   └── docker-compose.yml
├── apisix-devshare-plugin-runner/  # Go 插件项目
│   ├── plugins/
│   └── cmd/
└── devops-tools/           # 部署脚本
    └── scripts/
        └── setup-apisix.sh
```

**优点**：
- ✅ 职责清晰，插件和配置分离
- ✅ 可以独立版本管理
- ✅ 便于 CI/CD 构建

**缺点**：
- ⚠️ 需要管理多个仓库
- ⚠️ 部署时需要协调多个组件

#### 方案 B: Monorepo（推荐用于紧密耦合）

```
xinyuan_tech/
├── gateway/
│   ├── apisix/             # APISIX 配置
│   │   └── config.yaml
│   ├── plugins/            # Go 插件
│   │   └── apisix-devshare-plugin-runner/
│   └── docker-compose.yml
└── services/               # 业务服务
```

**优点**：
- ✅ 统一版本管理
- ✅ 便于整体部署
- ✅ 配置和代码在一起

**缺点**：
- ⚠️ 仓库体积较大
- ⚠️ 权限管理复杂

### 3. 生产环境发布策略

#### 方案 A: 自定义 Docker 镜像（推荐）

**步骤**：

1. **构建包含插件的 APISIX 镜像**：
   ```dockerfile
   # Dockerfile.apisix-custom
   FROM apache/apisix:3.14.1-debian
   
   # 复制自定义配置
   COPY apisix_conf/config.yaml /usr/local/apisix/conf/config.yaml
   
   # 复制 Go Plugin Runner 二进制
   COPY apisix-devshare-plugin-runner/bin/go-runner /usr/local/bin/go-runner
   RUN chmod +x /usr/local/bin/go-runner
   
   # 设置 ext-plugin 配置
   RUN echo 'ext-plugin:\n  cmd: ["/usr/local/bin/go-runner", "run"]' >> /usr/local/apisix/conf/config.yaml
   ```

2. **构建镜像**：
   ```bash
   docker build -f Dockerfile.apisix-custom -t xinyuan-tech/apisix:3.14.1-custom .
   ```

3. **推送到私有仓库**：
   ```bash
   docker tag xinyuan-tech/apisix:3.14.1-custom registry.example.com/xinyuan-tech/apisix:3.14.1-custom
   docker push registry.example.com/xinyuan-tech/apisix:3.14.1-custom
   ```

4. **生产环境使用**：
   ```yaml
   # docker-compose.prod.yml
   services:
     apisix:
       image: registry.example.com/xinyuan-tech/apisix:3.14.1-custom
       restart: always
   ```

#### 方案 B: 配置文件挂载（推荐用于配置频繁变更）

**步骤**：

1. **构建插件镜像**：
   ```dockerfile
   # Dockerfile.plugin-runner
   FROM golang:1.21-alpine AS builder
   WORKDIR /build
   COPY apisix-devshare-plugin-runner/ .
   RUN go build -o go-runner ./cmd/go-runner

   FROM alpine:latest
   COPY --from=builder /build/go-runner /usr/local/bin/go-runner
   RUN chmod +x /usr/local/bin/go-runner
   ENTRYPOINT ["/usr/local/bin/go-runner", "run"]
   ```

2. **使用官方镜像 + 配置挂载**：
   ```yaml
   # docker-compose.prod.yml
   services:
     apisix:
       image: apache/apisix:3.14.1-debian
       volumes:
         - ./apisix_conf/config.yaml:/usr/local/apisix/conf/config.yaml:ro
       depends_on:
         - plugin-runner
     
     plugin-runner:
       image: registry.example.com/xinyuan-tech/plugin-runner:latest
       # 插件运行配置
   ```

## 推荐方案

### 维护策略：独立维护 + Git Subtree

**理由**：
1. 自定义配置较多（Admin Key、ext-plugin 配置等）
2. 需要保留官方历史，便于参考
3. 可以选择性同步官方更新

**实施步骤**：

1. **初始化 Git Subtree**（如果还没有）：
   ```bash
   cd /Users/gaoyong/Documents/work/xinyuan_tech
   
   # 如果 apisix-docker 还没有 git 历史，先初始化
   cd apisix-docker
   git init
   git add .
   git commit -m "Initial commit: Custom APISIX configuration"
   
   # 添加官方仓库为 remote
   git remote add upstream https://github.com/apache/apisix-docker.git
   ```

2. **同步官方更新**（定期执行）：
   ```bash
   cd apisix-docker
   git fetch upstream
   git merge upstream/main --no-edit
   # 解决冲突（如果有）
   ```

### 项目结构：保持分离

**当前结构（推荐保持）**：
```
xinyuan_tech/
├── apisix-docker/              # APISIX 配置（独立维护）
│   └── example/
│       └── apisix_conf/
│           └── config.yaml
├── apisix-devshare-plugin-runner/  # Go 插件（独立维护）
│   └── plugins/
└── devops-tools/               # 部署脚本
    └── scripts/
        └── setup-apisix.sh
```

**理由**：
1. 职责清晰：配置、插件、脚本分离
2. 独立版本管理：可以独立发布和版本控制
3. 便于 CI/CD：可以分别构建和测试

### 生产环境发布：自定义镜像 + 配置管理

**推荐方案**：

1. **构建自定义 APISIX 镜像**（包含插件）
2. **使用配置管理工具**（如 Ansible、Terraform）
3. **版本化配置**（Git 管理）
4. **CI/CD 自动化**（构建、测试、部署）

## 实施建议

### 短期（1-2 周）

1. **确定维护策略**：
   - 选择独立维护或 Fork
   - 建立同步机制（如果选择 Fork）

2. **整理自定义配置**：
   - 将自定义配置文档化
   - 创建配置模板

3. **建立构建流程**：
   - 创建 Dockerfile
   - 建立 CI/CD 流程

### 中期（1-2 月）

1. **完善文档**：
   - 维护策略文档
   - 部署文档
   - 配置说明文档

2. **建立监控**：
   - 配置健康检查
   - 建立日志收集

3. **优化流程**：
   - 自动化测试
   - 自动化部署

### 长期（持续）

1. **定期同步官方更新**：
   - 每月检查官方更新
   - 评估是否需要同步

2. **持续优化**：
   - 优化镜像大小
   - 优化启动时间
   - 优化配置管理

## 参考

- [Git Subtree 使用指南](https://www.atlassian.com/git/tutorials/git-subtree)
- [Docker 最佳实践](https://docs.docker.com/develop/dev-best-practices/)
- [APISIX 官方文档](https://apisix.apache.org/zh/docs/apisix/installation-guide/)
