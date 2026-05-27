#!/bin/bash
# CodeDeploy - AfterInstall: instalar dependências
set -e

echo "=== AfterInstall: Instalando dependências ==="

cd /opt/app

# Instalar Node.js se não existir
if ! command -v node &> /dev/null; then
  echo "Instalando Node.js 20..."
  curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
  yum install -y nodejs
fi

# Instalar dependências de produção
npm ci --production

# Ajustar permissões
chown -R ec2-user:ec2-user /opt/app

echo "Dependências instaladas com sucesso."
