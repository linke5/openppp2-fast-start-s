#!/bin/bash
# 快速安装和启动 openppp2-s 的脚本

script_dir=$(dirname "$(realpath "$0")")
ppp_dir="$script_dir/openppp2"
exec_start="$ppp_dir/ppp"
restart_policy="always"
config_file="openppp2/appsettings.json"

# 检查并安装依赖工具的函数
check_install_dependency() {
    local dependency=$1
    local install_command=$2
    if ! command -v "$dependency" &> /dev/null; then
        echo "$dependency 未找到，尝试安装..."
        eval "$install_command"
        if ! command -v "$dependency" &> /dev/null; then
            echo "安装 $dependency 失败。请手动安装 $dependency 并重试。"
            exit 1
        fi
    fi
}

# 安装所需工具（如果不存在）
check_install_dependency jq "sudo apt update && sudo apt install -y jq"
check_install_dependency unzip "sudo apt install -y unzip"
check_install_dependency tmux "sudo apt install -y tmux"

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
curl -L -o openppp2-latest.zip "$download_url"

if [ $? -ne 0 ]; then
    echo "下载 openppp2 最新版本失败。"
    exit 1
else
    echo "成功下载 openppp2 最新版本。"
fi

# 解压下载的文件
echo "正在解压文件到 openppp2 目录..."
unzip -o openppp2-latest.zip -d openppp2

if [ $? -ne 0 ]; then
    echo "解压文件失败。"
    exit 1
else
    echo "成功解压文件到 openppp2 目录。"
fi

# 设置文件权限
echo "设置 openppp2 目录下所有文件的权限为 755..."
chmod -R 755 openppp2

if [ $? -ne 0 ]; then
    echo "设置文件权限失败。"
    exit 1
else
    echo "成功设置 openppp2 目录下所有文件的权限为 755。"
fi

# 用户输入函数，带默认值
read_input() {
    local prompt=$1
    local var_name=$2
    local default_value=$3
    read -p "$prompt [$default_value]: " input
    eval "$var_name=\"${input:-$default_value}\""
}

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
default_backedn_status="off"
default_ws_status="off"
default_wss_status="off"

# 提示用户输入参数

echo "[]内为默认值"

read -p "请输入工作线程数 [$default_concurrent]: " concurrent
concurrent=${concurrent:-$default_concurrent}

read -p "请输入加密协议 [$default_protocol]: " protocol
protocol=${protocol:-$default_protocol}

read -p "请输入加密密钥 [$default_protocol_key]: " protocol_key
protocol_key=${protocol_key:-$default_protocol_key}

read -p "请输入传输加密协议 [$default_transport]: " transport
transport=${transport:-$default_transport}

read -p "请输入加密密钥 [$default_transport_key]: " transport_key
transport_key=${transport_key:-$default_transport_key}

read -p "请输入监听 IP [$default_ip_config]: " ip_config
ip_config=${ip_config:-$default_ip_config}

read -p "请输入 PPP TCP 协议监听端口 [$default_listen_port_tcp_ppp]: " listen_port_tcp_ppp
listen_port_tcp_ppp=${listen_port_tcp_ppp:-$default_listen_port_tcp_ppp}

read -p "请输入 PPP UDP 协议监听端口 [$default_listen_port_udp_ppp]: " listen_port_udp_ppp
listen_port_udp_ppp=${listen_port_udp_ppp:-$default_listen_port_udp_ppp}

read -p "请输入 WS 协议监听端口 [$default_listen_port_tcp_ws]: " listen_port_tcp_ws
listen_port_tcp_ws=${listen_port_tcp_ws:-$default_listen_port_tcp_ws}

read -p "请输入 WSS 协议监听端口 [$default_listen_port_tcp_wss]: " listen_port_tcp_wss
listen_port_tcp_wss=${listen_port_tcp_wss:-$default_listen_port_tcp_wss}

read -p "请输入 WS 协议 Host [$default_ws_host]: " ws_host
ws_host=${ws_host:-$default_ws_host}

read -p "请输入 ws 协议 Path [$default_ws_path]: " ws_path
ws_path=${ws_path:-$default_ws_path}

read -p "请输入管理 API URL [$default_backend]: " backend
backend=${backend:-$default_backend}

read -p "请输入管理 API KEY [$default_backend_key]: " backend_key
backend_key=${backend_key:-$default_backend_key}

read -p "是否开启管理接口(默认关闭，开启请输入 on )" backend_status
backend_status=${backend_status:-$default_backend_status}

read -p "是否开启WS连接协议(默认关闭，开启请输入 on)" 

# 确认用户输入的参数
echo "参数设置如下："
echo "concurrent = $concurrent"
echo "protocol = $protocol"
echo "protocol_key = $protocol_key"
echo "transport = $transport"
echo "transport_key = $transport_key"
echo "ip_config = $ip_config"
echo "listen_port_tcp_ppp = $listen_port_tcp_ppp"
echo "listen_port_udp_ppp = $listen_port_udp_ppp"
echo "listen_port_tcp_ws = $listen_port_tcp_ws"
echo "listen_port_tcp_wss = $listen_port_tcp_wss"
echo "ws_host = $ws_host"
echo "ws_path = $ws_path"
echo "backend = $backend"
echo "backend_key = $backend_key"
echo "管理接口开启状态 $backend_status"

# 更新 openppp2/appsettings.json 文件
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
    .websocket.path = $ws_path |
    .websocket.listen.ws = ($listen_port_tcp_ws | tonumber) |
    .websocket.listen.wss = ($listen_port_tcp_wss | tonumber) |
    .server.backend = $backend |
    .server["backend-key"] = $backend_key' openppp2/appsettings.json > openppp2/appsettings_tmp.json

# 替换原始文件
mv openppp2/appsettings_tmp.json openppp2/appsettings.json

total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_mem_mb=$((total_mem_kb / 1024))
memory_threshold=256
if [[ $total_mem_mb -ge $memory_threshold ]]; then
    jq 'del(.vmem)' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
    echo "vmem 部分已删除"
else
    echo "系统内存小于 $memory_threshold MB，未删除 vmem 部分"
fi


if [[ $backend_status == off ]]; then
	jq 'del(.server.backend)' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
	jq 'del(.server["backend-key"])' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
	echo "管理接口部分已删除，管理功能关闭"
else
	echo "管理接口部分未删除，管理功能开启"
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
WorkingDirectory=$ppp_dir
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
    tmux new-session -d -s ppp2-s "cd $ppp_dir && ./ppp"
    echo "PPP 已在 tmux 会话中启动。"

# 无效输入
else
    echo "无效输入，请运行脚本并选择 1 或 2。"
    exit 1
fi

