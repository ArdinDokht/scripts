#!/bin/bash

TOOLS=("curl" "git" "python3" "python3-pip" "nodejs" "npm" "docker.io" "docker-compose" "kubeadm" "kubectl" "golang-go" "nginx" "postgresql" "redis-server" "openjdk-11-jdk")

echo "🔍 Starting installation tests..."
echo "==============================" > install_log.txt

for tool in "${TOOLS[@]}"; do
    echo -n "🛠️  Installing $tool ... "
    echo "------ $tool ------" >> install_log.txt

    sudo apt-get install -y $tool >> install_log.txt 2>&1

    if [ $? -eq 0 ]; then
        echo "✅ Installed successfully"
        echo "[✔] $tool installed successfully" >> install_log.txt
    else
        echo "❌ Installation failed"
        echo "[✘] $tool installation failed" >> install_log.txt
    fi

    echo "------------------------------" >> install_log.txt
done

echo "📄 Logs saved to install_log.txt"
