#!/bin/bash
# User data para EC2 do SonarQube + Grafana + PostgreSQL
# Tudo na mesma instância para simplificar a POC

set -e

# Atualizar sistema
yum update -y
yum install -y docker git

# Iniciar Docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Configurar sysctl para SonarQube (Elasticsearch)
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
echo "fs.file-max=131072" >> /etc/sysctl.conf
sysctl -p

# Criar diretório para docker-compose
mkdir -p /opt/devsecops
cd /opt/devsecops

# Criar docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # PostgreSQL para SonarQube
  sonarqube-db:
    image: postgres:15
    container_name: sonarqube-db
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: ${sonar_db_pass}
      POSTGRES_DB: sonarqube
    volumes:
      - sonarqube_db_data:/var/lib/postgresql/data
    restart: unless-stopped

  # SonarQube Community
  sonarqube:
    image: sonarqube:10-community
    container_name: sonarqube
    depends_on:
      - sonarqube-db
    ports:
      - "9000:9000"
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://sonarqube-db:5432/sonarqube
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: ${sonar_db_pass}
      SONAR_WEB_JAVAADDITIONALOPTS: "-Xmx512m -Xms512m"
      SONAR_CE_JAVAADDITIONALOPTS: "-Xmx2g -Xms1g"
      SONAR_SEARCH_JAVAADDITIONALOPTS: "-Xmx1g -Xms1g"
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    ulimits:
      nofile:
        soft: 131072
        hard: 131072
    restart: unless-stopped

  # PostgreSQL para Grafana (métricas consolidadas)
  grafana-db:
    image: postgres:15
    container_name: grafana-db
    environment:
      POSTGRES_USER: grafana
      POSTGRES_PASSWORD: grafana123
      POSTGRES_DB: sonar_metrics
    ports:
      - "5432:5432"
    volumes:
      - grafana_db_data:/var/lib/postgresql/data
      - ./init-grafana-db.sql:/docker-entrypoint-initdb.d/init.sql
    restart: unless-stopped

  # Grafana
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    depends_on:
      - grafana-db
    ports:
      - "3001:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin123
      GF_INSTALL_PLUGINS: grafana-clock-panel
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana-provisioning:/etc/grafana/provisioning
    restart: unless-stopped

volumes:
  sonarqube_db_data:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  grafana_db_data:
  grafana_data:
EOF

# Script SQL para inicializar banco de métricas do Grafana
cat > init-grafana-db.sql << 'EOSQL'
-- Tabela de métricas extraídas do SonarQube (similar ao que a Senior faz)
CREATE TABLE IF NOT EXISTS sonar_project_metrics (
  id SERIAL PRIMARY KEY,
  project_key VARCHAR(255) NOT NULL,
  project_name VARCHAR(255),
  product_line VARCHAR(100),
  module_name VARCHAR(100),
  coverage DECIMAL(5,2),
  duplicated_lines_pct DECIMAL(5,2),
  bugs INTEGER DEFAULT 0,
  vulnerabilities INTEGER DEFAULT 0,
  code_smells INTEGER DEFAULT 0,
  security_hotspots INTEGER DEFAULT 0,
  blocker_issues INTEGER DEFAULT 0,
  critical_issues INTEGER DEFAULT 0,
  major_issues INTEGER DEFAULT 0,
  minor_issues INTEGER DEFAULT 0,
  ncloc INTEGER DEFAULT 0,
  quality_gate_status VARCHAR(20),
  collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para consultas do Grafana
CREATE INDEX idx_metrics_project ON sonar_project_metrics(project_key);
CREATE INDEX idx_metrics_product_line ON sonar_project_metrics(product_line);
CREATE INDEX idx_metrics_module ON sonar_project_metrics(module_name);
CREATE INDEX idx_metrics_collected_at ON sonar_project_metrics(collected_at);

-- Tabela de análises (para tracking de tempo de análise)
CREATE TABLE IF NOT EXISTS sonar_analysis_log (
  id SERIAL PRIMARY KEY,
  project_key VARCHAR(255) NOT NULL,
  branch VARCHAR(255),
  analysis_duration_ms INTEGER,
  status VARCHAR(50),
  analyzed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOSQL

# Criar diretório de provisioning do Grafana
mkdir -p grafana-provisioning/datasources
mkdir -p grafana-provisioning/dashboards

# Datasource PostgreSQL para Grafana
cat > grafana-provisioning/datasources/postgres.yml << 'EOF'
apiVersion: 1
datasources:
  - name: SonarMetrics
    type: postgres
    url: grafana-db:5432
    database: sonar_metrics
    user: grafana
    secureJsonData:
      password: grafana123
    jsonData:
      sslmode: disable
      postgresVersion: 1500
EOF

# Iniciar serviços
docker-compose up -d

echo "SonarQube + Grafana instalados com sucesso!"
echo "SonarQube: http://localhost:9000 (admin/admin)"
echo "Grafana: http://localhost:3001 (admin/admin123)"
