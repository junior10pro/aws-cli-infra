#!/bin/bash
set -ex

# ---- Mise à jour système et installation Python ----
dnf update -y
dnf install -y python3 python3-pip

# ---- Dépendances Python ----
pip3 install flask gunicorn requests

# ---- Dépôt de l'application ----
mkdir -p /opt/web

cat > /opt/web/web.py << 'WEB_PY_EOF'
${web_py}
WEB_PY_EOF

# ---- Fichier d'environnement (DNS de l'ALB interne injecté par Terraform) ----
cat > /opt/web/.env << 'ENV_EOF'
INTERNAL_ALB_DNS=${internal_alb_dns}
ENV_EOF

chmod 600 /opt/web/.env

# ---- Service systemd ----
cat > /etc/systemd/system/webfront.service << 'SVC_EOF'
[Unit]
Description=Web Tier Frontend (Flask/Gunicorn)
After=network.target

[Service]
WorkingDirectory=/opt/web
EnvironmentFile=/opt/web/.env
ExecStart=/usr/local/bin/gunicorn -w 2 -b 0.0.0.0:80 web:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC_EOF

systemctl daemon-reload
systemctl enable webfront
systemctl start webfront
