#!/bin/bash
# 快速安装和启动 openppp2-s 的脚本

set -e

# Define installation directories

install_dir="/usr/local/bin/openppp2"
config_dir="/etc/openppp2"
unzip_dir="/tmp/ppp2"
lib_dir="/usr/local/lib/openppp2"
log_dir="/var/log/openppp2"

exec_start="$install_dir/ppp"
restart_policy="always"
config_file="$config_dir/appsettings.json"

default_concurrent="1"
default_protocol="aes-128-cfb"
default_protocol_key="N6HMzdUs7IUnYHwq"
default_transport="aes-256-cfb"
default_transport_key="HWFweXu2g5RVMEpy"
default_ip_config="::"
default_listen_port_tcp_ppp="20000"
default_listen_port_udp_ppp="20000"
default_listen_port_tcp_ws="20080"
default_listen_port_tcp_wss="20443"
default_ws_host="www.apple.com"
default_ws_path="/tun"
default_backend="ws://192.168.0.24/ppp/webhook"
default_backend_key="HaEkTB55VcHovKtUPHmU9zn0NjFmC6tff"
default_backend_status="off"
default_ws_status="off"
default_wss_status="off"
default_cdn_support_status="off"

# 检查并安装依赖工具的函数
check_install_dependency() {
    local dependency=$1
    local install_command=$2
    if ! command -v "$dependency" &> /dev/null; then
        echo "$dependency 未找到，尝试安装..."
        if ! eval "$install_command"; then
            echo "安装 $dependency 失败。请手动安装 $dependency 并重试。"
            exit 1
        fi
    fi
}

check_systeminfo() {
    # 判断机器架构
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64) arch="aarch64" ;;
        armv7l) arch="armv7l" ;;
        mipsel) arch="mipsel" ;;
        ppc64el) arch="ppc64el" ;;
        riscv64) arch="riscv64" ;;
        s390x) arch="s390x" ;;
        *) echo "不支持的架构: $arch"; exit 1 ;;
    esac   
}

config_appsettings() {
    # 用户输入函数，带默认值
    read_input() {
        local prompt=$1
        local var_name=$2
        local default_value=$3
        read -p "$prompt [$default_value]: " input
        eval "$var_name=\"${input:-$default_value}\""
    }

    # 提示用户输入参数
    echo "[]内为默认值"
    read_input "请输入工作线程数" concurrent $default_concurrent
    read_input "请输入加密协议" protocol $default_protocol
    read_input "请输入加密密钥" protocol_key $default_protocol_key
    read_input "请输入传输加密协议" transport $default_transport
    read_input "请输入加密密钥" transport_key $default_transport_key
    read_input "请输入监听 IP" ip_config $default_ip_config
    read_input "请输入 PPP TCP 协议监听端口" listen_port_tcp_ppp $default_listen_port_tcp_ppp
    read_input "请输入 PPP UDP 协议监听端口" listen_port_udp_ppp $default_listen_port_udp_ppp
    read_input "请输入 WS 协议监听端口" listen_port_tcp_ws $default_listen_port_tcp_ws
    read_input "请输入 WSS 协议监听端口" listen_port_tcp_wss $default_listen_port_tcp_wss
    read_input "请输入 WS 协议 Host" ws_host $default_ws_host
    read_input "请输入 WS 协议 Path" ws_path $default_ws_path
    read_input "请输入管理 API URL" backend $default_backend
    read_input "请输入管理 API KEY" backend_key $default_backend_key
    read_input "是否开启管理接口(默认关闭,开启请输入 on)" backend_status $default_backend_status
    read_input "是否开启 WS 连接协议(默认关闭.开启请输入 on)" ws_status $default_ws_status
    read_input "是否开启 WSS 连接协议(默认关闭,开启请输入 on)" wss_status $default_wss_status
    read_input "是否开启 CDN 支持(默认关闭,开启请输入 on)" cdn_support_status $default_cdn_support_status

    # 确认用户输入的参数
    echo "参数设置如下："
    echo "运行线程数 = $concurrent"
    echo "protocol = $protocol"
    echo "protocol_key = $protocol_key"
    echo "transport = $transport"
    echo "transport_key = $transport_key"
    echo "监听 IP = $ip_config"
    echo "PPP TCP 监听端口 = $listen_port_tcp_ppp"
    echo "PPP UDP 监听端口 = $listen_port_udp_ppp"
    echo "WS 监听端口 = $listen_port_tcp_ws"
    echo "WSS 监听端口 = $listen_port_tcp_wss"
    echo "WS Host Info = $ws_host"
    echo "WS Path Info = $ws_path"
    echo "backend = $backend"
    echo "backend_key = $backend_key"
    echo "管理接口开启状态 = $backend_status"
    echo "WS 协议开启状态 = $ws_status"
    echo "WSS 协议开启状态 = $wss_status"
    echo "CDN 支持开启状态 = $cdn_support_status"

    # 更新配置文件
    jq --arg concurrent "$concurrent" \
       --arg protocol "$protocol" \
       --arg protocol_key "$protocol_key" \
       --arg transport "$transport" \
       --arg transport_key "$transport_key" \
       --arg ip_config "$ip_config" \
       --arg listen_port_tcp_ppp "$listen_port_tcp_ppp" \
       --arg listen_port_udp_ppp "$listen_port_udp_ppp" \
       --arg listen_port_tcp_ws "$listen_port_tcp_ws" \
       --arg listen_port_tcp_wss "$listen_port_tcp_wss" \
       --arg ws_host "$ws_host" \
       --arg ws_path "$ws_path" \
       --arg backend "$backend" \
       --arg backend_key "$backend_key" \
       '.concurrent = ($concurrent | tonumber) |
        .key.protocol = $protocol |
        .key["protocol-key"] = $protocol_key |
        .key.transport = $transport |
        .key["transport-key"] = $transport_key |
        .ip.public = $ip_config |
        .ip.interface = $ip_config |
        .tcp.listen.port = ($listen_port_tcp_ppp | tonumber) |
        .udp.listen.port = ($listen_port_udp_ppp | tonumber) |
        .websocket.host = $ws_host |
        .websocket.path 
        = $ws_path |
        .websocket.listen.ws = ($listen_port_tcp_ws | tonumber) |
        .websocket.listen.wss = ($listen_port_tcp_wss | tonumber) |
        .server.backend = $backend |
        .server["backend-key"] = $backend_key' "$config_file" > "${config_file}.tmp"

    # 替换原始文件
    mv "${config_file}.tmp" "$config_file"

    # 删除 vmem 部分，如果内存大于 96MB
    total_mem_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    if [[ $total_mem_mb -ge 96 ]]; then
        jq 'del(.vmem)' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
        echo "vmem 部分已删除"
    else
        echo "系统内存小于 96 MB，未删除 vmem 部分"
    fi

    # 检查 backend_status 并删除相应配置
    if [[ $backend_status == "off" ]]; then
        jq 'del(.server.backend, .server["backend-key"])' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
        echo "管理接口部分已删除，管理功能关闭"
    else
        echo "管理接口部分未删除，管理功能开启"
    fi

    # 检查 ws_status 和 wss_status 并删除相应配置
    if [[ $ws_status == "off" ]]; then
        jq 'del(.websocket.listen.ws)' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
        echo "已关闭 WS 协议支持"
    fi
    if [[ $wss_status == "off" ]]; then
        jq 'del(.websocket.listen.wss)' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
        echo "已关闭 WSS 协议支持"
    fi

    # 检查 cdn_support_status 并删除相应配置
    if [[ $cdn_support_status == "off" ]]; then
        jq 'del(.cdn)' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
        echo "已关闭 CDN 支持"
    else
        echo "未关闭 CDN 支持"
    fi
}

get_openppp2() {
    # 获取 openppp2 的最新发布版本
    latest_release=$(curl -s https://api.github.com/repos/liulilittle/openppp2/releases/latest)

    # 获取 IP 地址的地理位置信息
    response=$(curl -s ipinfo.io)
    country_code=$(echo "$response" | jq -r '.country')

    # 判断地理位置并设置下载源
    if [ "$country_code" == "CN" ]; then
        echo "检测到您的机器位于中国，使用加速源。"
    else
        echo "检测到您的机器位于海外，使用 GitHub 官方源。"
    fi

    # 提取适合架构的下载 URL
    download_url=$(echo "$latest_release" | jq -r --arg arch "$arch" '.assets[] | select(.name | test($arch)) | .browser_download_url' | head -n 1)

    if [ -z "$download_url" ]; then
        echo "未找到适合架构的下载 URL: $arch"
        exit 1
    fi

    # 下载最新发布版本
    echo "正在从 GitHub 下载适用于 $arch 的 openppp2 最新版本..."
    if ! curl -L -o openppp2-latest.zip "$download_url"; then
        echo "下载 openppp2 最新版本失败。"
        exit 1
    fi
    echo "成功下载 openppp2 最新版本。"

    # 解压下载的文件
    echo "正在解压文件到临时目录..."
    unzip_dir=$(mktemp -d)
    if ! unzip -o openppp2-latest.zip -d "$unzip_dir"; then
        echo "解压文件失败。"
        exit 1
    fi
    echo "成功解压文件。"

    # 移动文件到安装目录
    echo "安装 openppp2 到 $install_dir ..."
    mkdir -p "$install_dir" "$config_dir" "$lib_dir" "$log_dir"
    mv "$unzip_dir"/* "$install_dir"
    mv "$install_dir"/appsettings.jsom "$config_dir"
    echo "成功安装 openppp2。"

    # 设置文件权限
    echo "设置 $install_dir 目录下所有文件的权限为 755..."
    chmod -R 755 "$install_dir"
    echo "成功设置 $install_dir 目录下所有文件的权限为 755。"

    # 清理临时文件
    rm -rf "$unzip_dir" openppp2-latest.zip
}

# 检查 tmux 会话是否存在
check_tmux_session() {
    tmux_list=$(tmux ls 2>/dev/null || true)
    found_ppp2_s="Not Running"
    while IFS= read -r line; do
        session_name=$(echo "$line" | awk -F: '{print $1}')
        if [[ "$session_name" == *"ppp2-s"* ]]; then
            found_ppp2_s="Running"
            break
        fi
    done <<< "$tmux_list"
}

# 检查 systemd 服务状态
check_systemctl_ppp2() {
    status_output=$(systemctl status ppp 2>&1 || true)
    if [[ $status_output =~ "could not be found" ]]; then
        systemctl_status="Not Running"
    else
        systemctl_status="Running"
    fi
}

deploy_openppp2() {
    # 检查 tmux 会话和 systemd 服务状态
    check_tmux_session
    check_systemctl_ppp2

    # 如果 tmux 会话或 systemd 服务存在，则退出并返回错误
    if [[ $found_ppp2_s == "Running" ]] || [[ $systemctl_status == "Running" ]]; then
        echo "ppp2-s tmux 会话或 systemd 服务已经存在，安装中止。"
        exit 1
    fi

    # 选择部署方式
    echo "请选择部署方式："
    echo "1. 使用 systemd 服务"
    echo "2. 使用 tmux 会话"
    read -p "输入 1 或 2 进行选择: " deploy_method

    # 使用 systemd 部署
    if [ "$deploy_method" == "1" ]; then
        echo "配置 systemd 服务..."
        cat > /etc/systemd/system/ppp.service << EOF
[Unit]
Description=PPP service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$install_dir
ExecStart=$exec_start
Restart=$restart_policy
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable ppp.service
        systemctl start ppp.service
        echo "PPP 服务已配置并启动。"

    # 使用 tmux 部署
    elif [ "$deploy_method" == "2" ]; then
        echo "创建 tmux 会话并启动 PPP..."
        tmux new-session -d -s ppp2-s "cd $install_dir && ./ppp"
        check_tmux_session
        if [[ $found_ppp2_s == "Running" ]]; then
            echo "PPP 已在 tmux 会话中启动"
        else
            echo "PPP 启动失败，请手动运行或者更换安装方式"
            exit 1
        fi

    # 无效输入
    else
        echo "无效输入，请运行脚本并选择 1 或 2。"
        exit 1
    fi
}

# 安装所需工具（如果不存在）
check_install_dependency jq "sudo apt update && sudo apt install -y jq"
check_install_dependency unzip "sudo apt install -y unzip"
check_install_dependency tmux "sudo apt install -y tmux"

check_systeminfo
get_openppp2
config_appsettings
deploy_openppp2
