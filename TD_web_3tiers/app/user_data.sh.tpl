#!/bin/bash
set -ex

# ---- Mise à jour système et installation Python ----
dnf update -y
dnf install -y python3 python3-pip

# ---- Dépendances Python ----
pip3 install flask gunicorn psycopg2-binary bcrypt

# ---- Dépôt de l'application ----
mkdir -p /opt/app

cat > /opt/app/app.py << 'APP_PY_EOF'
${app_py}
APP_PY_EOF

# ---- Fichier d'environnement (credentials RDS injectés par Terraform) ----
# Le heredoc single-quoté empêche bash d'interpréter les $ dans les valeurs
cat > /opt/app/.env << 'ENV_EOF'
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
ENV_EOF

chmod 600 /opt/app/.env

# ---- Service systemd ----
cat > /etc/systemd/system/appapi.service << 'SVC_EOF'
[Unit]
Description=App Tier API (Flask/Gunicorn)
After=network.target

[Service]
WorkingDirectory=/opt/app
EnvironmentFile=/opt/app/.env
ExecStart=/usr/local/bin/gunicorn -w 2 -b 0.0.0.0:80 app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVC_EOF

systemctl daemon-reload
systemctl enable appapi
systemctl start appapi
