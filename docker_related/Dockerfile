# 多阶段构建Dockerfile - 支持多架构 (linux/amd64, linux/arm64)
FROM rust:1.82 as builder

# 获取目标架构信息
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "Building on $BUILDPLATFORM, targeting $TARGETPLATFORM"

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

# 复制二进制文件
COPY --from=builder /app/target/release/ipv6filter /usr/local/bin/ipv6filter

# 设置权限
RUN chown ipv6filter:ipv6filter /usr/local/bin/ipv6filter && \
    chmod +x /usr/local/bin/ipv6filter

# 创建配置目录（可选，因为程序会自动使用环境变量）
RUN mkdir -p /etc/ipv6filter && \
    chown ipv6filter:ipv6filter /etc/ipv6filter

# 切换到非root用户
USER ipv6filter

# 暴露DNS端口
EXPOSE 53/udp

# 设置环境变量
ENV RUST_LOG=info
ENV UPSTREAM_DNS="223.5.5.5:53,114.114.114.114:53,8.8.8.8:53"

# 运行IPv6Filter（直接运行二进制文件，支持环境变量配置）
CMD ["/usr/local/bin/ipv6filter"]
