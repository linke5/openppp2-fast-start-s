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
    organization_name=("Google" "Amazon" "Azure" "Alibaba" "Tencent" "Huawei")
    
    ip_out=$(curl -s -4 https://get.geojs.io/v1/ip)
    ip_local=($(ip a | awk '/inet / {print $2}' | cut -d/ -f1))
    unspecified_ips=("0.0.0.0" "::")
    
    if [[ " ${unspecified_ips[*]} " == *" $ip_config "* ]]; then
        ip_config=$ip_out
        echo "因未指定默认监听 IP "
        echo "连接 IP 将配置为出口 IP $ip_config"
    elif [[ " ${ip_local[*]} " == *" $ip_config "* ]]; then
        echo "监听 IP 与接口 IP 相同"
        echo "连接 IP 将配置为 $ip_config"
    else
        echo "出口 IP 与 接口 IP 皆不符合监听 IP"
        
        ip_out_geo=$(curl -s -4 https://get.geojs.io/v1/ip/geo.json | jq -r '.organization_name')
        pattern=$(IFS="|"; echo "${organization_name[*]}")
        
        if echo "$ip_out_geo" | grep -iqE "$pattern"; then
            echo "检测到 VPC 架构 默认使用出口 IP"
            ip_config=$ip_out
            echo "连接 IP 将配置为 $ip_config"
        else
            echo "无法正确判断连接IP"
            echo "请选择连接 IP"
            echo "1.接口 IP"
            echo "2.出口 IP"
            read -p "请选择连接 IP (1/2): " customize_ip
            
            if [[ $customize_ip == 1 ]]; then
                echo "将使用接口 IP 作为连接 IP"
                ip_config=$ip_local
            elif [[ $customize_ip == 2 ]]; then
                echo "将使用出口 IP 作为连接 IP"
                ip_config=$ip_out
            else
                echo "默认使用出口 IP 作为连接 IP"
                ip_config=$ip_out
            fi
        fi
    fi
}

generate_config() {
    check_ip
    cat > $server_config_dir/client/appsettings.json << EOF
{
    "concurrent": 1,
    "key": {
        "kf": 154543927,
        "kx": 128,
        "kl": 10,
        "kh": 12,
        "protocol": "$protocol",
        "protocol-key": "$transport_key",
        "transport": "$transport",
        "transport-key": "$transport_key",
        "masked": false,
        "plaintext": false,
        "delta-encode": false,
        "shuffle-data": false
    },
    "ip": {
        "public": "::",
        "interface": "::"
    },
    "tcp": {
        "inactive": {
            "timeout": 300
        },
        "connect": {
            "timeout": 5
        },
        "listen": {
            "port": 20000
        },
        "turbo": true,
        "backlog": 511,
        "fast-open": true
    },
    "udp": {
        "inactive": {
            "timeout": 72
        },
        "dns": {
            "timeout": 4,
            "redirect": "0.0.0.0"
        },
        "listen": {
            "port": 20000
        },
        "static": {
            "keep-alived": [ 300, 600 ],
            "dns": true,
            "quic": true,
            "icmp": true,
            "aggligator": 0,
            "servers": [ "$ip_config:$listen_port_udp_ppp" ]
        }
    },
    "client": {
        "guid": "{$(cat /proc/sys/kernel/random/uuid)}",
        "server": "ppp://$ip_config:$listen_port_tcp_ppp/",
        "reconnections": {
            "timeout": 5
        },        
        "http-proxy": {
            "bind": "127.0.0.1",
            "port": 7890
        }
    }
}
EOF
echo "已存放在 $server_config_dir/client/appsettings.json "
echo "Windows 运行指令: --mode=client --tun-ip=10.0.0.2 --tun-gw=10.0.0.0 --tun-mask=24 --tun-vnet=yes --tun-static=yes"
echo "非Windows 运行指令: --mode=client --tun-ip=10.0.0.2 --tun-gw=10.0.0.1 --tun-mask=24 --tun-vnet=yes --tun-static=yes"
echo "注: 每个客户端的 UUID 与 Tun-IP 应当为唯一值"
}

generate_config
check_install_dependency jq "sudo apt update && sudo apt install -y jq"
