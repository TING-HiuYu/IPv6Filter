#!/bin/bash

# Docker启动脚本
# 用于处理环境变量并生成配置文件

CONFIG_FILE="/etc/ipv6filter/config.toml"

# 如果设置了UPSTREAM_DNS环境变量，动态生成配置文件
if [ ! -z "$UPSTREAM_DNS" ]; then
    echo "生成动态配置文件，上游DNS: $UPSTREAM_DNS"
    
    # 将逗号分隔的DNS服务器转换为TOML数组格式
    IFS=',' read -ra DNS_ARRAY <<< "$UPSTREAM_DNS"
    UPSTREAM_SERVERS=""
    for dns in "${DNS_ARRAY[@]}"; do
        dns=$(echo "$dns" | xargs)  # 去除空白字符
        if [ ! -z "$dns" ]; then
            UPSTREAM_SERVERS="$UPSTREAM_SERVERS    \"$dns\",\n"
        fi
    done
    # 移除最后一个逗号
    UPSTREAM_SERVERS=$(echo -e "$UPSTREAM_SERVERS" | sed '$ s/,$//')
    
    cat > "$CONFIG_FILE" << EOF
# IPv6Filter Docker配置文件

[server]
# 监听地址和端口
listen_addr = "0.0.0.0:53"

# 上游DNS服务器列表 (从环境变量设置)
upstream_servers = [
$UPSTREAM_SERVERS
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

    echo "配置文件已生成:"
    cat "$CONFIG_FILE"
fi

# 启动IPv6Filter
exec /usr/local/bin/ipv6filter "$@"
