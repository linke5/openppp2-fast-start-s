#!/bin/bash
# Script to fastly install and start openppp2-s

# 检查并安装jq工具
if ! command -v jq &> /dev/null
then
    echo "jq could not be found, attempting to install jq..."
    sudo apt update
    sudo apt install -y jq
    if ! command -v jq &> /dev/null
    then
        echo "Failed to install jq. Please install jq manually and try again."
        exit 1
    fi
fi

# 检查并安装unzip工具
if ! command -v unzip &> /dev/null
then
    echo "unzip could not be found, attempting to install unzip..."
    sudo apt install -y unzip
    if ! command -v unzip &> /dev/null
    then
        echo "Failed to install unzip. Please install unzip manually and try again."
        exit 1
    fi
fi

# 检查并安装tmux工具
if ! command -v tmux &> /dev/null
then
    echo "screen could not be found, attempting to install screen..."
    sudo apt install -y tmux
    if ! command -v tmux &> /dev/null
    then
        echo "Failed to install screen. Please install screen manually and try again."
        exit 1
    fi
fi
# 判断机器架构
arch=$(uname -m)
case "$arch" in
    x86_64)
        arch="amd64"
        ;;
    aarch64)
        arch="aarch64"
        ;;
    armv7l)
        arch="armv7l"
        ;;
    mipsel)
        arch="mipsel"
        ;;
    ppc64el)
        arch="ppc64el"
        ;;
    riscv64)
        arch="riscv64"
        ;;
    s390x)
        arch="s390x"
        ;;
    *)
        echo "Unsupported architecture: $arch"
        exit 1
        ;;
esac

# 获取openppp2的最新发布版本
latest_release=$(curl -s https://api.github.com/repos/liulilittle/openppp2/releases/latest)

# 获取IP地址的地理位置信息
response=$(curl -s ipinfo.io)

# 提取国家代码
country_code=$(echo "$response" | jq -r '.country')

# 判断地理位置
if [ "$country_code" == "CN" ]; then
    echo "检测到您的机器位于大陆，是否为您更换加速源"
else
    echo "检测到您的机器位于海外，默认使用Github官方源"
fi

# 获取openppp2的最新发布版本
latest_release=$(curl -s https://api.github.com/repos/liulilittle/openppp2/releases/latest)

# 提取合适的下载URL
download_url=$(echo "$latest_release" | jq -r --arg arch "$arch" '.assets[] | select(.name | test($arch)) | .browser_download_url' | head -n 1)

# 检查是否成功获取下载URL
if [ -z "$download_url" ]; then
    echo "Failed to find a suitable download URL for architecture: $arch"
    exit 1
fi

# 下载最新的发布版本
echo "Downloading the latest release of openppp2 from GitHub for $arch..."
curl -L -o openppp2-latest.zip "$download_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the latest release of openppp2."
    exit 1
else
    echo "Successfully downloaded the latest release of openppp2."
fi

# 解压下载的文件到openppp2目录
echo "Unzipping the downloaded file to openppp2 directory..."
unzip -o openppp2-latest.zip -d openppp2

if [ $? -ne 0 ]; then
    echo "Failed to unzip the downloaded file."
    exit 1
else
    echo "Successfully unzipped the file to openppp2 directory."
fi

# 设置openppp2目录下所有文件的权限为755
echo "Setting permissions to 755 for all files in openppp2 directory..."
chmod -R 755 openppp2

if [ $? -ne 0 ]; then
    echo "Failed to set permissions for the files."
    exit 1
else
    echo "Successfully set permissions to 755 for all files in openppp2 directory."
fi

# 配置openppp2配置文件
sed -i 's|"192.168.0.24"|"::"|g' ./openppp2/appsettings.json #监听所有IP
sed -i '/"cdn": \[ 80, 443 \],/d' ./openppp2/appsettings.json #删除CDN WS支持
sed -i '/"backend": "ws:\/\/192.168.0.24\/ppp\/webhook",/d' ./openppp2/appsettings.json
sed -i 's/"mapping": true,/"mapping": true/' ./openppp2/appsettings.json
sed -i '/"backend-key": "HaEkTB55VcHovKtUPHmU9zn0NjFmC6tff"/d' ./openppp2/appsettings.json #删除远程管理API支持
sed -i '/"wss": 20443/d' ./openppp2/appsettings.json 
sed -i 's/"ws": 20080,/"ws": 20080/' ./openppp2/appsettings.json #删除WSS支持

#创建 tmux-session 并启动
tmux new-session -d -s ppp2-s "cd openppp2 &&./ppp"
