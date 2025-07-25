# Smart DNS Server

一个用Rust编写的智能DNS服务器，能够自动过滤双栈域名的IPv6记录，减少IPv6连接延迟问题。

## 功能特点

- 🚀 **双栈过滤**: 对于同时有A和AAAA记录的双栈域名，自动丢弃AAAA记录
- 🌐 **纯IPv6保留**: 对于只有AAAA记录的纯IPv6域名，正常返回IPv6地址
- ⚡ **高性能**: 基于Tokio异步运行时，支持高并发
- 🔧 **灵活配置**: 支持配置文件自定义上游DNS服务器和过滤规则
- 📦 **多平台支持**: 支持Linux、macOS等多个平台
- 🐳 **Docker支持**: 提供Docker镜像，便于部署

## 工作原理

当DNS服务器接收到AAAA查询时：

1. 检查该域名是否同时存在A记录
2. 如果存在A记录（双栈域名），则返回空响应，强制客户端使用IPv4
3. 如果不存在A记录（纯IPv6域名），则正常返回AAAA记录

## 快速开始

### 使用预编译二进制文件

1. 从[Releases页面](https://github.com/TING-HiuYu/IPv6Filter/releases)下载适合你系统的二进制文件
2. 配置`config.toml`文件
3. 运行DNS服务器

### 使用自动部署脚本（推荐）

```bash
# 下载并运行部署脚本
wget https://raw.githubusercontent.com/TING-HiuYu/IPv6Filter/main/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

### 使用Docker

```bash
docker run -d \
  --name dns-server \
  -p 53:53/udp \
  --restart unless-stopped \
  ghcr.io/ting-hiuyu/ipv6filter:latest
```

## 配置说明

编辑`config.toml`文件来配置DNS服务器：

```toml
[server]
bind_address = "0.0.0.0:53"
upstream_dns = "223.5.5.5:53"
timeout_ms = 5000

[filtering]
enable_ipv6_filtering = true
filter_dual_stack = true

[logging]
level = "info"
```

## 管理服务

使用提供的管理脚本：

```bash
# 启动服务
sudo ./start.sh start

# 停止服务
sudo ./start.sh stop

# 重启服务
sudo ./start.sh restart

# 查看状态
sudo ./start.sh status

# 查看日志
sudo ./start.sh logs
```

## 测试

测试双栈域名过滤（应该返回空结果）：
```bash
dig @127.0.0.1 facebook.com AAAA
```

测试纯IPv6域名保留（应该返回IPv6地址）：
```bash
dig @127.0.0.1 6.ipw.cn AAAA
```

测试A记录查询（正常工作）：
```bash
dig @127.0.0.1 google.com A
```

## 开发

### 本地构建

```bash
# 克隆仓库
git clone https://github.com/TING-HiuYu/IPv6Filter.git
cd IPv6Filter

# 构建
cargo build --release

# 运行
sudo ./target/release/dns-server
```

### 跨平台编译

查看[BUILD.md](BUILD.md)了解如何使用GitHub Actions进行自动构建。

## 系统要求

- **内存**: 最少16MB RAM
- **网络**: 53/UDP端口访问权限
- **权限**: 需要root权限绑定53端口

## 许可证

MIT License

## 贡献

欢迎提交Issue和Pull Request！

## 说明

本项目专门用于解决双栈网络环境下IPv6连接速度慢的问题。通过智能过滤双栈域名的AAAA记录，可以强制使用IPv4连接，提升网络访问速度，同时保留纯IPv6网站的正常访问。
