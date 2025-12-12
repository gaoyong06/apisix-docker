# APISIX 快速开始（最简方案）

## 🚀 三步启动

### 1. 构建插件（一次性）

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-devshare-plugin-runner
make build
```

### 2. 启动服务

```bash
cd /Users/gaoyong/Documents/work/xinyuan_tech/apisix-docker/example
docker-compose -f docker-compose.simple.yml up -d
```

### 3. 验证

```bash
curl http://localhost:9180/apisix/admin/services \
  -H "X-API-KEY: xinyuan_tech_apisix_admin_key_2025_secure"
```

## ✅ 完成！

就这么简单！无需构建自定义镜像，无需复杂配置。

## 📝 日常操作

### 修改配置

```bash
# 编辑配置
vim apisix_conf/config.yaml

# 重启生效
docker-compose -f docker-compose.simple.yml restart apisix
```

### 更新插件

```bash
# 重新构建
cd ../../apisix-devshare-plugin-runner
make build

# 重启生效
cd ../../apisix-docker/example
docker-compose -f docker-compose.simple.yml restart apisix
```

## 🎯 为什么这么简单？

1. ✅ **使用官方镜像**：无需构建自定义镜像
2. ✅ **配置文件挂载**：修改立即生效
3. ✅ **插件二进制挂载**：独立构建，独立更新
4. ✅ **无需复杂配置**：开箱即用

## 📚 更多信息

- [简化部署方案](./SIMPLE_DEPLOYMENT.md)
- [快速开始指南](../example/README.simple.md)
