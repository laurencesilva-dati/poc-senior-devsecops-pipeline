#!/bin/bash
# User data para EC2 da aplicação Node.js + CodeDeploy Agent
set -e

# Atualizar sistema
yum update -y
yum install -y git ruby wget

# Instalar Node.js 20
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs

# Instalar CodeDeploy Agent
cd /tmp
wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
chmod +x ./install
./install auto
systemctl start codedeploy-agent
systemctl enable codedeploy-agent

# Criar diretório da aplicação
mkdir -p /opt/app
chown ec2-user:ec2-user /opt/app

# Variáveis de ambiente da aplicação
cat > /opt/app/.env << EOF
DB_HOST=${db_host}
DB_USER=${db_user}
DB_PASS=${db_pass}
DB_NAME=${db_name}
PORT=3000
NODE_ENV=production
EOF

chown ec2-user:ec2-user /opt/app/.env

echo "EC2 configurada com Node.js e CodeDeploy Agent."
