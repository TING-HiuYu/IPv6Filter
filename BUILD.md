# 构建说明

## 项目结构

```
IPv6Filter/
├── src/
│   └── main.rs              # 独立版本主程序（支持跨平台配置文件）
├── docker_related/
│   ├── main_docker.rs       # Docker版本主程序（支持环境变量）
│   ├── Dockerfile           # Docker构建文件
│   └── docker-entrypoint.sh # Docker启动脚本
├── .github/workflows/
│   ├── build.yml           # 多平台构建工作流
│   └── docker.yml          # Docker镜像构建工作流
└── config.toml             # 默认配置文件
```

## 版本差异

### 独立版本 (`src/main.rs`)
- 适用于直接在系统上运行
- 支持跨平台配置文件路径检测
- Linux: `/etc/ipv6filter/config.toml`
- Windows/macOS: `可执行文件目录/config.toml`

### Docker版本 (`docker_related/main_docker.rs`)
- 专为容器化部署设计
- 支持环境变量配置：`UPSTREAM_DNS`、`LISTEN_ADDR`、`FILTER_ENABLED`
- 自动生成配置文件或使用环境变量

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

- 推送到main分支（构建但不发布）
- 创建新的tag（构建并发布Release）
- 创建Pull Request（测试构建）

你可以在GitHub仓库的"Actions"标签页查看构建状态和日志。
