# 自动构建说明

## 使用GitHub Actions自动构建

### 1. 将项推荐使用静态链接版本 `ipv6filter-linux-x86_64-musl`：

```bash
# 下载二进制文件
wget https://github.com/TING-HiuYu/IPv6Filter/releases/latest/download/ipv6filter-linux-x86_64-musl

# 重命名并设置权限
mv ipv6filter-linux-x86_64-musl ipv6filter
chmod +x ipv6filter

# 创建配置文件
mkdir -p /etc/ipv6filter
cp config.toml /etc/ipv6filter/

# 运行
sudo ./ipv6filterash
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

- `ipv6filter-linux-x86_64` - 适用于大多数Linux发行版
- `ipv6filter-linux-x86_64-musl` - 静态链接版本，适用于任何Linux系统
- `ipv6filter-macos-arm64` - macOS Apple Silicon
- `ipv6filter-macos-x86_64` - macOS Intel

### 3. 在Debian服务器上部署

推荐使用静态链接版本 `dns-server-linux-x86_64-musl`：

```bash
# 下载二进制文件
wget https://github.com/TING-HiuYu/IPv6Filter/releases/latest/download/dns-server-linux-x86_64-musl

# 重命名并设置权限
mv dns-server-linux-x86_64-musl dns-server
chmod +x dns-server

# 创建配置文件
mkdir -p /etc/dns-server
cp config.toml /etc/dns-server/

# 运行
sudo ./dns-server
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
