#!/bin/bash

# DNS服务器部署脚本
# 用于在Debian/Ubuntu服务器上部署DNS服务器

set -e

# 配置变量
RELEASE_URL="https://github.com/YOUR_USERNAME/DNS/releases/latest"
BINARY_NAME="dns-server-linux-x86_64-musl"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/dns-server"
SERVICE_NAME="dns-server"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

# 检查系统架构
check_architecture() {
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" ]]; then
        log_error "不支持的架构: $ARCH"
        log_info "此脚本仅支持x86_64架构"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    log_info "更新包列表..."
    apt-get update

    log_info "安装必要依赖..."
    apt-get install -y curl wget ca-certificates
}

# 下载最新版本
download_binary() {
    log_info "获取最新版本信息..."
    
    # 获取最新release的下载URL
    DOWNLOAD_URL=$(curl -s https://api.github.com/repos/YOUR_USERNAME/DNS/releases/latest | \
                   grep "browser_download_url.*${BINARY_NAME}" | \
                   cut -d '"' -f 4)
    
    if [[ -z "$DOWNLOAD_URL" ]]; then
        log_error "无法获取下载链接"
        exit 1
    fi
    
    log_info "下载DNS服务器..."
    wget -O "/tmp/${BINARY_NAME}" "$DOWNLOAD_URL"
    
    # 验证下载
    if [[ ! -f "/tmp/${BINARY_NAME}" ]]; then
        log_error "下载失败"
        exit 1
    fi
    
    log_info "下载完成"
}

# 安装二进制文件
install_binary() {
    log_info "安装DNS服务器到 ${INSTALL_DIR}..."
    
    # 停止现有服务（如果存在）
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "停止现有服务..."
        systemctl stop "$SERVICE_NAME"
    fi
    
    # 安装二进制文件
    cp "/tmp/${BINARY_NAME}" "${INSTALL_DIR}/dns-server"
    chmod +x "${INSTALL_DIR}/dns-server"
    
    # 创建配置目录
    mkdir -p "$CONFIG_DIR"
    
    log_info "安装完成"
}

# 创建配置文件
create_config() {
    log_info "创建配置文件..."
    
    cat > "${CONFIG_DIR}/config.toml" << 'EOF'
# DNS服务器配置

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
EOF
    
    log_info "配置文件已创建: ${CONFIG_DIR}/config.toml"
}

# 创建systemd服务
create_service() {
    log_info "创建systemd服务..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Smart DNS Server with IPv6 Filtering
After=network.target
Wants=network.target

[Service]
Type=simple
User=dns-server
Group=dns-server
ExecStart=${INSTALL_DIR}/dns-server
WorkingDirectory=${CONFIG_DIR}
Environment=RUST_LOG=info
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${CONFIG_DIR}

# 网络权限
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
    
    # 创建dns-server用户
    if ! id "dns-server" &>/dev/null; then
        useradd -r -s /bin/false dns-server
        log_info "已创建dns-server用户"
    fi
    
    # 设置权限
    chown -R dns-server:dns-server "$CONFIG_DIR"
    
    # 重载systemd
    systemctl daemon-reload
    
    log_info "systemd服务已创建"
}

# 启动服务
start_service() {
    log_info "启动DNS服务器..."
    
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    
    # 检查服务状态
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "DNS服务器启动成功！"
        log_info "服务状态: $(systemctl is-active $SERVICE_NAME)"
        log_info "监听端口: 53"
    else
        log_error "DNS服务器启动失败"
        log_info "查看日志: journalctl -u $SERVICE_NAME -f"
        exit 1
    fi
}

# 显示使用信息
show_usage() {
    log_info "DNS服务器部署完成！"
    echo
    echo "常用命令:"
    echo "  查看状态: systemctl status $SERVICE_NAME"
    echo "  查看日志: journalctl -u $SERVICE_NAME -f"
    echo "  重启服务: systemctl restart $SERVICE_NAME"
    echo "  停止服务: systemctl stop $SERVICE_NAME"
    echo "  编辑配置: nano ${CONFIG_DIR}/config.toml"
    echo
    echo "测试DNS服务器:"
    echo "  dig @localhost google.com A"
    echo "  dig @localhost facebook.com AAAA"
    echo
    log_warn "记得在防火墙中开放53端口！"
}

# 主函数
main() {
    log_info "开始部署DNS服务器..."
    
    check_root
    check_architecture
    install_dependencies
    download_binary
    install_binary
    create_config
    create_service
    start_service
    show_usage
    
    log_info "部署完成！"
}

# 运行主函数
main "$@"
