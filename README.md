# 双栈域名过滤器

鉴于某些网站存在奇奇怪怪的IPv6支持问题，然后现在的大部分系统都是优先IPv6。这里用Rust编写了一个DNS服务器，用于自动丢弃上游对于双栈域名的AAAA记录解析，然后返回给下游。

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

## 许可证

MIT License
