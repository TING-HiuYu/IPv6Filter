# 多阶段构建Dockerfile
FROM rust:1.82 as builder

WORKDIR /app

# 复制源码
COPY . .

# 构建release版本（现在统一使用src/main.rs，支持环境变量）
RUN cargo build --release

# 运行时镜像 - 使用最小的Linux发行版
FROM debian:bookworm-slim

# 安装必要的运行时依赖
RUN apt-get update && \
    apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# 创建非root用户
RUN useradd -r -s /bin/false ipv6filter

# 复制二进制文件和启动脚本
COPY --from=builder /app/target/release/ipv6filter /usr/local/bin/ipv6filter
COPY docker_related/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# 设置权限
RUN chown ipv6filter:ipv6filter /usr/local/bin/ipv6filter && \
    chmod +x /usr/local/bin/ipv6filter && \
    chown ipv6filter:ipv6filter /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

# 创建配置目录
RUN mkdir -p /etc/ipv6filter && \
    chown ipv6filter:ipv6filter /etc/ipv6filter

# 复制默认配置
COPY config.toml /etc/ipv6filter/config.toml
RUN chown ipv6filter:ipv6filter /etc/ipv6filter/config.toml

# 切换到非root用户
USER ipv6filter

# 暴露DNS端口
EXPOSE 53/udp

# 设置环境变量
ENV RUST_LOG=info
ENV UPSTREAM_DNS="223.5.5.5:53,114.114.114.114:53,8.8.8.8:53"

# 运行IPv6Filter
CMD ["/usr/local/bin/docker-entrypoint.sh"]
