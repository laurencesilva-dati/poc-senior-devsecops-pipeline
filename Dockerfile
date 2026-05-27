# Dockerfile para a aplicação ERP Gestão de Pessoas
# Vulnerabilidade proposital: imagem base desatualizada, roda como root
FROM node:18-slim

WORKDIR /app

# Vulnerabilidade: copia tudo incluindo .env e secrets
COPY . .

RUN npm ci --production

# Vulnerabilidade: expõe porta sem TLS
EXPOSE 3000

# Vulnerabilidade: roda como root
USER root

CMD ["node", "src/server.js"]
