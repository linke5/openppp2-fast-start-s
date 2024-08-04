#!/bin/bash

server_config_dir="/etc/openppp2"
server_config_file="$server_config_dir/appsettings.json"

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

read_config_file() {
    protocol=$(jq -r '.key.protocol' "$server_config_file")
    protocol_key=$(jq -r '.key["protocol-key"]' "$server_config_file")
    transport=$(jq -r '.key.transport' "$server_config_file")
    transport_key=$(jq -r '.key["transport-key"]' "$server_config_file")
    listen_port_tcp_ppp=$(jq -r '.tcp.listen.port' "$server_config_file")
    listen_port_udp_ppp=$(jq -r '.udp.listen.port' "$config_file")
    ws_host=$(jq -r '.websocket.host' "$server_config_file")
    ws_path=$(jq -r '.websocket.path' "$server_config_file")
    ip_config=$(jq -r '.ip.public' "$config_file")
}

check_ip() {
    ip_out=$(curl -s -4 https://get.geojs.io/v1/ip.json)
    ip_local=($(ip a | awk '/inet / {print $2}' | cut -d/ -f1))
    unspecified_ips=("0.0.0.0" "::")
    if [[ $ip_config == ${unspecified_ips[@]} ]]; then
        ip_config=$(echo "$ip_out" | jq -r '.ip')
        echo "因未指定默认监听 IP "
        echo "连接 IP 将配置为 $ip_config "
    elif [[ $ip_config ==  ${ip_local[@]} ]]; then
        echo "监听 IP 与接口 IP 相同"
        echo "连接 IP 将配置为 $ip_config "
    
}

generate_config_file() {


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
       '.concurrent = ($concurrent | tonumber) |
        .key.protocol = $protocol |
        .key["protocol-key"] = $protocol_key |
        .key.transport = $transport |
        .key["transport-key"] = $transport_key |
        .tcp.listen.port = ($listen_port_tcp_ppp | tonumber) |
        .udp.listen.port = ($listen_port_udp_ppp | tonumber) |
        .udp.static.servers = "\($new_ip):\()"
        .websocket.host = $ws_host |
        .websocket.path 
        = $ws_path |
       ' "$config_file" > "${config_file}.tmp"
}



















check_install_dependency jq "sudo apt update && sudo apt install -y jq"
