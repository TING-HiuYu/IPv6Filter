# 构建说明

## 项目结构

```
IPv6Filter/
├── src/
│   └── main.rs              # 统一的主程序（支持配置文件和环境变量）
├── docker_related/
│   ├── Dockerfile           # Docker构建文件
│   └── docker-entrypoint.sh # Docker启动脚本
├── .github/workflows/
│   ├── build.yml           # 多平台构建工作流
│   └── docker.yml          # Docker镜像构建工作流
└── config.toml             # 默认配置文件
```

## 配置优先级

IPv6Filter现在使用更加合理的配置系统：

**配置优先级**: 配置文件 > 环境变量 > 默认值

- **配置文件存在**: 直接使用配置文件，**忽略所有环境变量**
- **配置文件不存在**: 使用环境变量，如果环境变量也没有则使用默认值

### 配置文件路径
- **Linux**: `/etc/ipv6filter/config.toml`
- **Windows/macOS**: `可执行文件目录/config.toml`

### 支持的环境变量
- `UPSTREAM_DNS`: 上游DNS服务器列表，用逗号分隔（例如："1.1.1.1:53,8.8.8.8:53"）
- `LISTEN_ADDR`: DNS服务器监听地址（例如："0.0.0.0:53"）
- `FILTER_ENABLED`: 是否启用IPv6过滤（true/false）
- `RUST_LOG`: 日志级别（error, warn, info, debug, trace）

### 配置示例

#### 使用配置文件
```toml
[server]
listen_addr = "0.0.0.0:53"
upstream_servers = ["223.5.5.5:53", "8.8.8.8:53"]

[filtering]
enabled = true
strategy = "dual_stack_only"

[logging]
level = "info"
enable_stats = true
```

#### 使用环境变量
```bash
export UPSTREAM_DNS="1.1.1.1:53,8.8.8.8:53"
export LISTEN_ADDR="0.0.0.0:53"
export FILTER_ENABLED="true"
export RUST_LOG="info"
./ipv6filter
```

#### Docker环境变量
```bash
docker run -d \
  --name ipv6filter \
  -p 53:53/udp \
  -e UPSTREAM_DNS="223.5.5.5:53,114.114.114.114:53" \
  -e FILTER_ENABLED="true" \
  ghcr.io/ting-hiuyu/ipv6filter:latest
```

## 使用GitHub Actions自动构建

### 1. 将项目推送到GitHub

```bash
cd /Users/hiuyuting/Code/DNS

# 初始化git仓库（如果还没有）
git init

# 添加所有文件
git add .

# 提交
git commit -m "Initial commit: Smart DNS Server with IPv6 filtering"

# 添加远程仓库（替换YOUR_USERNAME为你的GitHub用户名）
git remote add origin https://github.com/TING-HiuYu/IPv6Filter.git

# 推送到GitHub
git push -u origin main
```

### 2. 创建Release来触发构建

在GitHub上创建一个新的Release：

1. 进入你的GitHub仓库
2. 点击 "Releases" → "Create a new release"
3. 输入标签版本，例如：`v1.0.0`
4. 输入Release标题和描述
5. 点击 "Publish release"

GitHub Actions会自动构建以下版本：

- **跨平台二进制文件**: Linux (x86_64/aarch64), Windows (x86_64), macOS (x86_64/Apple Silicon)
- **Docker镜像**: 多架构支持 (linux/amd64, linux/arm64)
- **Release资源**: 包含所有平台的二进制文件和Docker镜像tar文件

### 3. 构建完成后的文件

构建完成后，Release中会包含：

#### 二进制文件
- `ipv6filter-linux-x86_64` - Linux x86_64版本
- `ipv6filter-linux-x86_64-musl` - Linux x86_64静态链接版本（推荐）
- `ipv6filter-linux-aarch64` - Linux ARM64版本
- `ipv6filter-windows-x86_64.exe` - Windows x86_64版本
- `ipv6filter-macos-x86_64` - macOS Intel版本
- `ipv6filter-macos-aarch64` - macOS Apple Silicon版本

#### Docker镜像
- **Container Registry**: `ghcr.io/ting-hiuyu/ipv6filter:latest`
- **Docker文件**: `ipv6filter-docker-image.tar` (可下载并本地导入)

### 4. Linux服务器部署

推荐使用静态链接版本 `ipv6filter-linux-x86_64-musl`：

```bash
# 下载二进制文件
wget https://github.com/TING-HiuYu/IPv6Filter/releases/latest/download/ipv6filter-linux-x86_64-musl

# 重命名并设置权限
mv ipv6filter-linux-x86_64-musl ipv6filter
chmod +x ipv6filter

# 创建配置文件
sudo mkdir -p /etc/ipv6filter
sudo cp config.toml /etc/ipv6filter/

# 运行测试
sudo ./ipv6filter
```

### 4. 使用自动部署脚本

更简单的方式是使用提供的部署脚本：

```bash
# 下载部署脚本
wget https://raw.githubusercontent.com/TING-HiuYu/IPv6Filter/main/deploy.sh

# 设置权限
chmod +x deploy.sh

# 运行部署（需要root权限）
sudo ./deploy.sh
```

部署脚本会自动：
- 下载最新版本的二进制文件
- 创建systemd服务
- 配置自动启动
- 设置适当的权限

### 5. Docker部署（可选）

如果你的服务器支持Docker：

```bash
# 拉取镜像
docker pull ghcr.io/ting-hiuyu/ipv6filter:latest

# 运行容器
docker run -d \
  --name ipv6filter \
  -p 53:53/udp \
  --restart unless-stopped \
  ghcr.io/ting-hiuyu/ipv6filter:latest
```

## 构建状态

GitHub Actions会在以下情况触发构建：

- 创建新的tag（自动构建并发布Release）
- 手动触发工作流（在GitHub Actions页面点击"Run workflow"按钮）

你可以在GitHub仓库的"Actions"标签页查看构建状态和日志。

### 手动触发构建

如果需要手动触发构建（例如测试或调试），可以：

1. 进入GitHub仓库的"Actions"标签页
2. 选择要运行的工作流（"Build and Release"或"Docker Build"）
3. 点击"Run workflow"按钮
4. 选择分支（通常是main）
5. 点击绿色的"Run workflow"按钮
