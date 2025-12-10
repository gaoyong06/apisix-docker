# APISIX 简化部署指南

## 快速开始

### 1. 构建插件（一次性）

```bash
# 构建 Go 插件
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-devshare-plugin-runner
make build

# 验证插件是否构建成功
ls -lh bin/go-runner
```

### 2. 启动服务

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-docker/example

# 使用简化版配置启动
docker-compose -f docker-compose.simple.yml up -d

# 查看日志
docker-compose -f docker-compose.simple.yml logs -f apisix
```

### 3. 验证部署

```bash
# 检查服务状态
docker-compose -f docker-compose.simple.yml ps

# 测试 Admin API
curl http://localhost:9180/apisix/admin/services \
  -H "X-API-KEY: xinyuan_tech_apisix_admin_key_2025_secure"
```

## 日常操作

### 修改配置

```bash
# 1. 编辑配置文件
vim apisix_conf/config.yaml

# 2. 重启 APISIX（配置会自动重新加载）
docker-compose -f docker-compose.simple.yml restart apisix
```

### 更新插件

```bash
# 1. 重新构建插件
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-devshare-plugin-runner
make build

# 2. 重启 APISIX（会使用新的插件二进制）
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-docker/example
docker-compose -f docker-compose.simple.yml restart apisix
```

### 查看日志

```bash
# APISIX 日志
docker-compose -f docker-compose.simple.yml logs -f apisix

# etcd 日志
docker-compose -f docker-compose.simple.yml logs -f etcd

# 所有服务日志
docker-compose -f docker-compose.simple.yml logs -f
```

### 停止服务

```bash
docker-compose -f docker-compose.simple.yml down

# 停止并删除数据卷（谨慎使用）
docker-compose -f docker-compose.simple.yml down -v
```

## 配置说明

### 文件结构

```
example/
├── docker-compose.simple.yml  # 简化版 Docker Compose 配置
├── apisix_conf/
│   └── config.yaml            # APISIX 配置文件
└── README.simple.md           # 本文件
```

### 关键配置

1. **APISIX 镜像**：使用官方镜像 `apache/apisix:3.14.1-debian`
2. **配置文件**：挂载 `apisix_conf/config.yaml`
3. **插件二进制**：挂载 `../../apisix-devshare-plugin-runner/bin/go-runner`

### 修改配置路径

如果插件路径不同，修改 `docker-compose.simple.yml`：

```yaml
volumes:
  - /your/path/to/go-runner:/usr/local/bin/go-runner:ro
```

## 优势

✅ **简单**：无需构建自定义镜像  
✅ **灵活**：配置修改立即生效  
✅ **稳定**：使用官方镜像  
✅ **易维护**：插件独立构建和管理  

## 故障排查

### 插件未加载

1. 检查插件是否构建成功：
   ```bash
   ls -lh ../../apisix-devshare-plugin-runner/bin/go-runner
   ```

2. 检查挂载路径是否正确：
   ```bash
   docker-compose -f docker-compose.simple.yml exec apisix ls -lh /usr/local/bin/go-runner
   ```

3. 检查 APISIX 配置：
   ```bash
   docker-compose -f docker-compose.simple.yml exec apisix cat /usr/local/apisix/conf/config.yaml | grep ext-plugin
   ```

### 配置未生效

1. 检查配置文件是否正确挂载：
   ```bash
   docker-compose -f docker-compose.simple.yml exec apisix cat /usr/local/apisix/conf/config.yaml
   ```

2. 检查 APISIX 是否重新加载：
   ```bash
   docker-compose -f docker-compose.simple.yml exec apisix apisix reload
   ```

### 服务无法启动

1. 检查端口是否被占用：
   ```bash
   lsof -i :9080
   lsof -i :9180
   ```

2. 查看详细日志：
   ```bash
   docker-compose -f docker-compose.simple.yml logs apisix
   ```

## 生产环境建议

1. **限制 Admin API 访问**：
   ```yaml
   allow_admin:
     - 10.0.0.0/8  # 仅允许内网访问
   ```

2. **使用环境变量管理密钥**：
   ```yaml
   environment:
     - APISIX_ADMIN_KEY=${APISIX_ADMIN_KEY}
   ```

3. **配置健康检查**（已包含在 docker-compose.simple.yml）

4. **定期备份 etcd 数据**：
   ```bash
   docker-compose -f docker-compose.simple.yml exec etcd etcdctl snapshot save /backup/etcd-snapshot.db
   ```

## 参考

- [APISIX 官方文档](https://apisix.apache.org/zh/docs/apisix/installation-guide/)
- [简化部署方案文档](../docs/SIMPLE_DEPLOYMENT.md)
