#!/bin/bash
# CodeDeploy - ApplicationStart: iniciar a aplicação
set -e

echo "=== ApplicationStart: Iniciando aplicação ==="

# Criar serviço systemd se não existir
cat > /etc/systemd/system/erp-app.service << 'EOF'
[Unit]
Description=ERP Gestao de Pessoas - POC DevSecOps
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/app
EnvironmentFile=/opt/app/.env
ExecStart=/usr/bin/node src/server.js
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable erp-app
systemctl start erp-app

echo "Aplicação iniciada na porta 3000."
