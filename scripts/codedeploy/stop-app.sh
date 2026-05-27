#!/bin/bash
# CodeDeploy - ApplicationStop: parar a aplicação
echo "=== ApplicationStop: Parando aplicação ==="

systemctl stop erp-app 2>/dev/null || true

echo "Aplicação parada."
