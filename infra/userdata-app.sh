#!/bin/bash
# User data para EC2 da aplicação Node.js
set -e

# Atualizar sistema
yum update -y
yum install -y git

# Instalar Node.js 20
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs

# Criar diretório da aplicação
mkdir -p /opt/app
cd /opt/app

# Variáveis de ambiente da aplicação
cat > /opt/app/.env << EOF
DB_HOST=${db_host}
DB_USER=${db_user}
DB_PASS=${db_pass}
DB_NAME=${db_name}
PORT=3000
EOF

# Criar serviço systemd
cat > /etc/systemd/system/erp-app.service << 'EOF'
[Unit]
Description=ERP Gestao de Pessoas
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/app
EnvironmentFile=/opt/app/.env
ExecStart=/usr/bin/node src/server.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "EC2 da aplicação configurada. Deploy do código será feito via CodeBuild."
