#!/bin/bash

# IPv6Filter 启动脚本
# 使用方法: ./start.sh [start|stop|restart|status]

SERVICE_NAME="ipv6filter"
BINARY_PATH="/usr/local/bin/ipv6filter"
CONFIG_PATH="/etc/ipv6filter/config.toml"
PID_FILE="/var/run/ipv6filter.pid"
LOG_FILE="/var/log/ipv6filter.log"

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
    echo "请以root权限运行此脚本"
    exit 1
fi

start_service() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "IPv6Filter已经在运行 (PID: $PID)"
            return 1
        else
            rm -f "$PID_FILE"
        fi
    fi

    echo "启动IPv6Filter..."
    nohup "$BINARY_PATH" > "$LOG_FILE" 2>&1 &
    PID=$!
    echo $PID > "$PID_FILE"
    
    sleep 2
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "IPv6Filter启动成功 (PID: $PID)"
        echo "配置文件: $CONFIG_PATH"
        echo "日志文件: $LOG_FILE"
    else
        echo "IPv6Filter启动失败，请检查日志: $LOG_FILE"
        rm -f "$PID_FILE"
        return 1
    fi
}

stop_service() {
    if [ ! -f "$PID_FILE" ]; then
        echo "IPv6Filter未运行"
        return 1
    fi

    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "停止IPv6Filter (PID: $PID)..."
        kill "$PID"
        
        # 等待进程结束
        for i in {1..10}; do
            if ! ps -p "$PID" > /dev/null 2>&1; then
                break
            fi
            sleep 1
        done
        
        # 如果进程仍在运行，强制结束
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "强制停止IPv6Filter..."
            kill -9 "$PID"
        fi
        
        rm -f "$PID_FILE"
        echo "IPv6Filter已停止"
    else
        echo "IPv6Filter进程不存在，清理PID文件"
        rm -f "$PID_FILE"
    fi
}

status_service() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "IPv6Filter正在运行 (PID: $PID)"
            
            # 显示内存和CPU使用情况
            echo "进程信息:"
            ps -p "$PID" -o pid,ppid,pcpu,pmem,vsz,rss,tty,stat,start,time,command
            
            # 显示监听端口
            echo "监听端口:"
            netstat -tulpn | grep ":53 " | grep "$PID" 2>/dev/null || echo "未检测到53端口监听"
            
            return 0
        else
            echo "IPv6Filter未运行 (PID文件存在但进程不存在)"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        echo "IPv6Filter未运行"
        return 1
    fi
}

restart_service() {
    echo "重启IPv6Filter..."
    stop_service
    sleep 2
    start_service
}

case "$1" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    status)
        status_service
        ;;
    logs)
        if [ -f "$LOG_FILE" ]; then
            tail -f "$LOG_FILE"
        else
            echo "日志文件不存在: $LOG_FILE"
        fi
        ;;
    *)
        echo "使用方法: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "命令说明:"
        echo "  start   - 启动IPv6Filter"
        echo "  stop    - 停止IPv6Filter"
        echo "  restart - 重启IPv6Filter"
        echo "  status  - 显示服务器状态"
        echo "  logs    - 实时查看日志"
        exit 1
        ;;
esac
