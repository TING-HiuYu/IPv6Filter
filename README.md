# IPv6Filter - 双栈域名过滤器

鉴于某些网站存在奇奇怪怪的IPv6支持问题，然后现在的大部分系统都是优先IPv6。这里用Rust编写了一个DNS服务器，用于自动丢弃上游对于双栈域名的AAAA记录解析，然后返回给下游。

## 功能特点

- 🚀 **双栈过滤**: 对于同时有A和AAAA记录的双栈域名，自动丢弃AAAA记录
- 🌐 **纯IPv6保留**: 对于只有AAAA记录的纯IPv6域名，正常返回IPv6地址
- ⚡ **高性能**: 基于Tokio异步运行时，支持高并发
- 🔧 **灵活配置**: 支持TOML配置文件和环境变量，跨平台路径自动检测
- 📦 **多平台支持**: 支持Linux、macOS、Windows等多个平台，包含ARM64架构
- 🐳 **Docker支持**: 提供多架构Docker镜像，便于部署
- 🔒 **安全运行**: systemd服务集成，非特权用户运行

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

#### 平台选择指南
- **Linux x86_64服务器**: 推荐 `ipv6filter-linux-x86_64-musl`（静态链接，兼容性最好）
- **Raspberry Pi/ARM单板机**: 使用 `ipv6filter-linux-aarch64`
- **Windows x86_64**: 使用 `ipv6filter-windows-x86_64.exe`
- **macOS Intel**: 使用 `ipv6filter-macos-x86_64`
- **macOS Apple Silicon**: 使用 `ipv6filter-macos-aarch64`

### 使用自动部署脚本（推荐）

```bash
# 下载并运行部署脚本
wget https://raw.githubusercontent.com/TING-HiuYu/IPv6Filter/main/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

### 使用Docker

基本运行：
```bash
docker run -d \
  --name ipv6filter \
  -p 53:53/udp \
  --restart unless-stopped \
  ghcr.io/ting-hiuyu/ipv6filter:latest
```

自定义上游DNS服务器：
```bash
docker run -d \
  --name ipv6filter \
  -p 53:53/udp \
  -e UPSTREAM_DNS="1.1.1.1:53,8.8.8.8:53" \
  --restart unless-stopped \
  ghcr.io/ting-hiuyu/ipv6filter:latest
```

完整配置示例：
```bash
docker run -d \
  --name ipv6filter \
  -p 53:53/udp \
  -e UPSTREAM_DNS="223.5.5.5:53,114.114.114.114:53,1.1.1.1:53" \
  -e RUST_LOG=debug \
  --restart unless-stopped \
  ghcr.io/ting-hiuyu/ipv6filter:latest
```

#### 环境变量支持

IPv6Filter支持通过环境变量配置（适用于Docker和独立部署）：

- `UPSTREAM_DNS`: 上游DNS服务器列表，用逗号分隔（例如："223.5.5.5:53,8.8.8.8:53"）
- `LISTEN_ADDR`: DNS服务器监听地址（默认："0.0.0.0:53"）
- `FILTER_ENABLED`: 是否启用IPv6过滤（true/false，默认：true）
- `RUST_LOG`: 日志级别（error, warn, info, debug, trace）

**配置优先级**: 
- **配置文件存在**: 使用配置文件，忽略环境变量
- **配置文件不存在**: 使用环境变量，如果环境变量也没有则使用默认值

#### 独立部署环境变量示例
```bash
export UPSTREAM_DNS="1.1.1.1:53,8.8.8.8:53"
export LISTEN_ADDR="0.0.0.0:53"
export FILTER_ENABLED="true"
./ipv6filter
```

也可以下载Docker镜像文件：
从[Releases页面](https://github.com/TING-HiuYu/IPv6Filter/releases)下载`ipv6filter-docker-image.tar`文件，然后：
```bash
docker load < ipv6filter-docker-image.tar
docker run -d --name ipv6filter -p 53:53/udp ipv6filter:latest
```

## 配置说明

IPv6Filter使用统一的配置系统，会根据运行平台自动选择配置文件路径：
- **Linux**: `/etc/ipv6filter/config.toml`
- **Windows**: `可执行文件目录/config.toml`
- **macOS**: `可执行文件目录/config.toml`

编辑`config.toml`文件来配置IPv6Filter：

```toml
# IPv6Filter配置文件

[server]
# 监听地址和端口
listen_addr = "0.0.0.0:53"

# 上游DNS服务器列表
upstream_servers = [
    "223.5.5.5:53",      # 阿里DNS
    "114.114.114.114:53", # 114DNS
    "8.8.8.8:53",        # Google DNS
]

# IPv6过滤配置
[filtering]
# 是否启用IPv6记录过滤
enabled = true

# 过滤策略
strategy = "dual_stack_only"

[logging]
# 日志级别
level = "info"

# 是否记录DNS查询统计
enable_stats = true
```

## 管理服务

### systemd服务管理（Linux）

```bash
# 查看状态
sudo systemctl status ipv6filter

# 查看日志
sudo journalctl -u ipv6filter -f

# 重启服务
sudo systemctl restart ipv6filter

# 停止服务
sudo systemctl stop ipv6filter

# 编辑配置
sudo nano /etc/ipv6filter/config.toml
```

### 手动管理脚本

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

## 部署选项

### 方式一：自动部署脚本（推荐）
适用于Linux服务器，自动安装systemd服务：
```bash
wget https://raw.githubusercontent.com/TING-HiuYu/IPv6Filter/main/deploy.sh
chmod +x deploy.sh
sudo ./deploy.sh
```

### 方式二：Docker部署
```bash
# 基本部署
docker run -d \
  --name ipv6filter \
  -p 53:53/udp \
  --restart unless-stopped \
  ghcr.io/ting-hiuyu/ipv6filter:latest

# 自定义上游DNS
docker run -d \
  --name ipv6filter \
  -p 53:53/udp \
  -e UPSTREAM_DNS="1.1.1.1:53,8.8.8.8:53" \
  --restart unless-stopped \
  ghcr.io/ting-hiuyu/ipv6filter:latest
```

### 方式三：手动二进制部署
1. 从[Releases页面](https://github.com/TING-HiuYu/IPv6Filter/releases)下载对应平台的二进制文件
2. 推荐下载`ipv6filter-linux-x86_64-musl`（静态链接，无依赖）
3. 设置执行权限并运行

## 开发

### 本地构建

```bash
# 克隆仓库
git clone https://github.com/TING-HiuYu/IPv6Filter.git
cd IPv6Filter

# 构建
cargo build --release

# 运行
sudo ./target/release/ipv6filter
```

### 跨平台编译

查看[BUILD.md](BUILD.md)了解如何使用GitHub Actions进行自动构建。

## 系统要求

- **内存**: 最少16MB RAM
- **网络**: 53/UDP端口访问权限
- **权限**: 需要root权限绑定53端口（或使用非特权端口）

## 许可证

MIT License

## 说明

欢迎提交Issue和Pull Request！

本项目专门用于解决双栈网络环境下IPv6连接速度慢的问题。通过智能过滤双栈域名的AAAA记录，可以强制使用IPv4连接，提升网络访问速度，同时保留纯IPv6网站的正常访问。

## AI声明

项目中的Github Action和md文件是用AI生成的
