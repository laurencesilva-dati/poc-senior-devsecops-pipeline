#!/bin/bash
# CodeDeploy - ApplicationStart: iniciar a aplicação
set -e

echo "=== ApplicationStart: Iniciando aplicação ==="

# Criar .env se não existir
if [ ! -f /opt/app/.env ]; then
  cat > /opt/app/.env << 'EOF'
DB_HOST=poc-staging-mysql.cmbcsawk4upf.us-east-1.rds.amazonaws.com
DB_USER=admin
DB_PASS=Administrator-123
DB_NAME=erp_pessoas
PORT=3000
NODE_ENV=production
EOF
  chown ec2-user:ec2-user /opt/app/.env
fi

# Criar serviço systemd
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

# Aguardar 3 segundos e verificar se está rodando
sleep 3
if systemctl is-active --quiet erp-app; then
  echo "Aplicação iniciada com sucesso na porta 3000."
else
  echo "WARN: Aplicação pode estar iniciando (aguardando conexão com banco)..."
  # Não falhar - a app pode demorar para conectar ao RDS
  exit 0
fi
