#!/bin/bash
# CodeDeploy - AfterInstall: instalar dependências
set -e

echo "=== AfterInstall: Instalando dependências ==="

cd /opt/app

# Instalar Node.js se não existir
if ! command -v node &> /dev/null; then
  echo "Instalando Node.js 20..."
  dnf install -y nodejs npm || {
    curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
    dnf install -y nodejs || yum install -y nodejs
  }
fi

echo "Node.js version: $(node --version)"

# Instalar dependências de produção
if [ -f package.json ]; then
  npm ci --production --ignore-scripts 2>/dev/null || npm install --production --ignore-scripts
fi

# Ajustar permissões
chown -R ec2-user:ec2-user /opt/app

echo "Dependências instaladas com sucesso."
