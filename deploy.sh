#!/bin/bash

# DNS服务器部署脚本
# 用于在Debian/Ubuntu服务器上部署DNS服务器

set -e

# 配置变量
RELEASE_URL="https://github.com/TING-HiuYu/IPv6Filter/releases/latest"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/ipv6filter"
SERVICE_NAME="ipv6filter"

# 自动检测架构和确定二进制文件名
detect_binary_name() {
    local arch=$(uname -m)
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$arch" in
        x86_64|amd64)
            BINARY_NAME="ipv6filter-linux-x86_64"
            ;;
        aarch64|arm64)
            BINARY_NAME="ipv6filter-linux-aarch64"
            ;;
        *)
            log_error "不支持的架构: $arch"
            log_info "支持的架构: x86_64, aarch64"
            exit 1
            ;;
    esac
    
    log_info "检测到架构: $arch"
    log_info "将下载二进制文件: $BINARY_NAME"
}

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

# 检查系统和架构
check_system() {
    # 检查操作系统
    if [[ "$(uname -s)" != "Linux" ]]; then
        log_error "此脚本仅支持Linux系统"
        exit 1
    fi
    
    # 检测二进制文件名
    detect_binary_name
    
    log_info "系统检查通过"
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
    DOWNLOAD_URL=$(curl -s https://api.github.com/repos/TING-HiuYu/IPv6Filter/releases/latest | \
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
    log_info "安装IPv6Filter到 ${INSTALL_DIR}..."
    
    # 停止现有服务（如果存在）
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "停止现有服务..."
        systemctl stop "$SERVICE_NAME"
    fi
    
    # 安装二进制文件
    cp "/tmp/${BINARY_NAME}" "${INSTALL_DIR}/ipv6filter"
    chmod +x "${INSTALL_DIR}/ipv6filter"
    
    # 创建配置目录
    mkdir -p "$CONFIG_DIR"
    
    log_info "安装完成"
}

# 创建配置文件
create_config() {
    log_info "创建配置文件..."
    
    cat > "${CONFIG_DIR}/config.toml" << 'EOF'
# IPv6Filter DNS服务器配置

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
Description=IPv6Filter - Smart DNS Server with IPv6 Filtering
After=network.target
Wants=network.target

[Service]
Type=simple
User=ipv6filter
Group=ipv6filter
ExecStart=${INSTALL_DIR}/ipv6filter
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
    
    # 创建ipv6filter用户
    if ! id "ipv6filter" &>/dev/null; then
        /usr/sbin/useradd -r -s /bin/false ipv6filter
        log_info "已创建ipv6filter用户"
    fi
    
    # 设置权限
    chown -R ipv6filter:ipv6filter "$CONFIG_DIR"
    
    # 重载systemd
    systemctl daemon-reload
    
    log_info "systemd服务已创建"
}

# 启动服务
start_service() {
    log_info "启动IPv6Filter服务..."
    
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    
    # 检查服务状态
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_info "IPv6Filter服务启动成功！"
        log_info "服务状态: $(systemctl is-active $SERVICE_NAME)"
        log_info "监听端口: 53"
    else
        log_error "IPv6Filter服务启动失败"
        log_info "查看日志: journalctl -u $SERVICE_NAME -f"
        exit 1
    fi
}

# 显示使用信息
show_usage() {
    log_info "IPv6Filter部署完成！"
    echo
    echo "常用命令:"
    echo "  查看状态: systemctl status $SERVICE_NAME"
    echo "  查看日志: journalctl -u $SERVICE_NAME -f"
    echo "  重启服务: systemctl restart $SERVICE_NAME"
    echo "  停止服务: systemctl stop $SERVICE_NAME"
    echo "  编辑配置: nano ${CONFIG_DIR}/config.toml"
    echo
    echo "测试IPv6Filter服务:"
    echo "  dig @localhost google.com A"
    echo "  dig @localhost facebook.com AAAA"
    echo
    log_warn "记得在防火墙中开放53端口！"
}

# 主函数
main() {
    log_info "开始部署IPv6Filter..."
    
    check_root
    check_system
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
