# 多阶段构建Dockerfile
FROM rust:1.82 as builder

WORKDIR /app

# 复制源码
COPY . .

# 构建release版本
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
RUN useradd -r -s /bin/false dns-server

# 复制二进制文件
COPY --from=builder /app/target/release/dns-server /usr/local/bin/dns-server

# 设置权限
RUN chown dns-server:dns-server /usr/local/bin/dns-server && \
    chmod +x /usr/local/bin/dns-server

# 创建配置目录
RUN mkdir -p /etc/dns-server && \
    chown dns-server:dns-server /etc/dns-server

# 复制默认配置
COPY config.toml /etc/dns-server/config.toml
RUN chown dns-server:dns-server /etc/dns-server/config.toml

# 切换到非root用户
USER dns-server

# 暴露DNS端口
EXPOSE 53/udp

# 设置环境变量
ENV RUST_LOG=info

# 运行DNS服务器
CMD ["/usr/local/bin/dns-server"]
