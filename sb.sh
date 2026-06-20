#!/bin/bash
set -e

echo "=============================="
echo " Reality Stable Enhanced v2 "
echo " DNS SAFE / Production Ready "
echo "=============================="

PORT=8443
SNI="www.microsoft.com"

# =========================
# 1. 基础依赖（不动系统网络）
# =========================
apt update -y
apt install -y curl wget uuid-runtime openssl ufw

# =========================
# 2. 安装 sing-box（防 404）
# =========================
echo "[INFO] Installing sing-box..."

bash <(curl -fsSL https://sing-box.app/deb-install.sh) || {
    echo "[ERROR] sing-box install failed"
    exit 1
}

# =========================
# 3. 检查 binary
# =========================
if ! command -v sing-box >/dev/null 2>&1; then
    echo "[ERROR] sing-box not found"
    exit 1
fi

# =========================
# 4. 生成参数
# =========================
UUID=$(cat /proc/sys/kernel/random/uuid)

KEYS=$(sing-box generate reality-keypair)

PRIVATE_KEY=$(echo "$KEYS" | awk '/PrivateKey/ {print $2}')
PUBLIC_KEY=$(echo "$KEYS" | awk '/PublicKey/ {print $2}')

SHORT_ID=$(openssl rand -hex 8)
IP=$(curl -4 -s ip.sb)

echo "[INFO] Server IP: $IP"

# =========================
# 5. 防端口占用检查
# =========================
if ss -tlnp | grep -q ":$PORT"; then
    echo "[ERROR] Port $PORT already in use"
    exit 1
fi

# =========================
# 6. 写配置（最小稳定核心）
# =========================
mkdir -p /etc/sing-box

cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "level": "info"
  },

  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": $PORT,

      "users": [
        {
          "uuid": "$UUID",
          "flow": "xtls-rprx-vision"
        }
      ],

      "tls": {
        "enabled": true,
        "server_name": "$SNI",

        "reality": {
          "enabled": true,

          "handshake": {
            "server": "$SNI",
            "server_port": 443
          },

          "private_key": "$PRIVATE_KEY",
          "short_id": ["$SHORT_ID"]
        }
      }
    }
  ],

  "outbounds": [
    { "type": "direct" }
  ]
}
EOF

# =========================
# 7. 配置检查（关键）
# =========================
echo "[INFO] Checking config..."
sing-box check -c /etc/sing-box/config.json

# =========================
# 8. systemd（稳定版）
# =========================
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box reality
After=network.target

[Service]
ExecStart=/usr/bin/sing-box run -c /etc/sing-box/config.json
Restart=always
RestartSec=3
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box

sleep 2

# =========================
# 9. 防火墙（只开端口）
# =========================
ufw allow $PORT/tcp || true

# =========================
# 10. 状态检查
# =========================
echo ""
echo "===== SERVICE STATUS ====="
systemctl status sing-box --no-pager -l || true

echo ""
echo "===== PORT CHECK ====="
ss -tlnp | grep $PORT || true

# =========================
# 11. 客户端输出（Passwall）
# =========================
echo ""
echo "================ CLIENT ================="
echo "Server     : $IP"
echo "Port       : $PORT"
echo "UUID       : $UUID"
echo "SNI        : $SNI"
echo "PublicKey  : $PUBLIC_KEY"
echo "ShortID    : $SHORT_ID"
echo "Flow       : xtls-rprx-vision"

echo ""
echo "VLESS URL:"
echo "vless://$UUID@$IP:$PORT?encryption=none&security=reality&flow=xtls-rprx-vision&sni=$SNI&pbk=$PUBLIC_KEY&sid=$SHORT_ID#Reality"