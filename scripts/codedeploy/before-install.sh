#!/bin/bash
# CodeDeploy - BeforeInstall: limpar diretório anterior
set -e

echo "=== BeforeInstall: Limpando diretório da aplicação ==="

# Parar aplicação se estiver rodando
systemctl stop erp-app 2>/dev/null || true

# Limpar diretório (exceto .env)
if [ -d /opt/app ]; then
  find /opt/app -mindepth 1 -not -name '.env' -delete 2>/dev/null || true
fi

mkdir -p /opt/app
echo "Diretório limpo."
