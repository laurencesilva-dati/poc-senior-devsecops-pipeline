#!/bin/bash
# EC2 dedicada: Grafana + PostgreSQL + Coletor de métricas do SonarQube
set -e

yum update -y
yum install -y docker git python3 python3-pip

# Iniciar Docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Criar estrutura
mkdir -p /opt/grafana
cd /opt/grafana

# ============================================================
# Docker Compose: PostgreSQL + Grafana
# ============================================================
cat > docker-compose.yml << 'COMPOSE'
version: '3.8'
services:
  postgres:
    image: postgres:15
    container_name: grafana-postgres
    environment:
      POSTGRES_USER: grafana
      POSTGRES_PASSWORD: grafana123
      POSTGRES_DB: sonar_metrics
    ports:
      - "5432:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/01-init.sql
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    depends_on:
      - postgres
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin123
      GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH: /var/lib/grafana/dashboards/painel-geral.json
    volumes:
      - grafana_data:/var/lib/grafana
      - ./provisioning:/etc/grafana/provisioning
      - ./dashboards:/var/lib/grafana/dashboards
    restart: unless-stopped

volumes:
  pg_data:
  grafana_data:
COMPOSE

# ============================================================
# SQL: Tabelas de métricas (reproduz o modelo da Senior)
# ============================================================
cat > init-db.sql << 'SQL'
-- Métricas por projeto (extração periódica do SonarQube)
CREATE TABLE IF NOT EXISTS sonar_project_metrics (
  id SERIAL PRIMARY KEY,
  project_key VARCHAR(255) NOT NULL,
  project_name VARCHAR(255),
  product_line VARCHAR(100) DEFAULT '',
  module_name VARCHAR(100) DEFAULT '',
  coverage DECIMAL(5,2) DEFAULT 0,
  duplicated_lines_pct DECIMAL(5,2) DEFAULT 0,
  bugs INTEGER DEFAULT 0,
  vulnerabilities INTEGER DEFAULT 0,
  code_smells INTEGER DEFAULT 0,
  security_hotspots INTEGER DEFAULT 0,
  blocker_issues INTEGER DEFAULT 0,
  critical_issues INTEGER DEFAULT 0,
  major_issues INTEGER DEFAULT 0,
  minor_issues INTEGER DEFAULT 0,
  ncloc INTEGER DEFAULT 0,
  quality_gate_status VARCHAR(20) DEFAULT 'NONE',
  security_rating VARCHAR(5) DEFAULT '',
  reliability_rating VARCHAR(5) DEFAULT '',
  nosonar_count INTEGER DEFAULT 0,
  collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_project_key ON sonar_project_metrics(project_key);
CREATE INDEX idx_product_line ON sonar_project_metrics(product_line);
CREATE INDEX idx_module ON sonar_project_metrics(module_name);
CREATE INDEX idx_collected_at ON sonar_project_metrics(collected_at);

-- Log de análises (tempo de processamento)
CREATE TABLE IF NOT EXISTS sonar_analysis_log (
  id SERIAL PRIMARY KEY,
  project_key VARCHAR(255) NOT NULL,
  task_id VARCHAR(255),
  status VARCHAR(50),
  duration_ms INTEGER DEFAULT 0,
  analyzed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
SQL

# ============================================================
# Grafana Provisioning: Datasource PostgreSQL
# ============================================================
mkdir -p provisioning/datasources provisioning/dashboards dashboards

cat > provisioning/datasources/postgres.yml << 'YAML'
apiVersion: 1
datasources:
  - name: SonarMetrics
    type: postgres
    access: proxy
    url: postgres:5432
    database: sonar_metrics
    user: grafana
    secureJsonData:
      password: grafana123
    jsonData:
      sslmode: disable
      postgresVersion: 1500
    isDefault: true
YAML

cat > provisioning/dashboards/default.yml << 'YAML'
apiVersion: 1
providers:
  - name: default
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: false
YAML

# ============================================================
# Dashboard: Painel Geral (similar ao da Senior)
# ============================================================
cat > dashboards/painel-geral.json << 'DASHBOARD'
{
  "annotations": {"list": []},
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "datasource": {"type": "postgres", "uid": ""},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "blue", "value": null}]}}, "overrides": []},
      "gridPos": {"h": 5, "w": 6, "x": 0, "y": 0},
      "options": {"colorMode": "background", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "value_and_name"},
      "title": "Projetos no Sonar",
      "type": "stat",
      "targets": [{"rawSql": "SELECT COUNT(DISTINCT project_key) as \"Quantidade de projetos\" FROM sonar_project_metrics WHERE collected_at = (SELECT MAX(collected_at) FROM sonar_project_metrics)", "format": "table"}]
    },
    {
      "datasource": {"type": "postgres", "uid": ""},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "green", "value": null}, {"color": "yellow", "value": 40}, {"color": "red", "value": 30}]}, "unit": "percent"}, "overrides": []},
      "gridPos": {"h": 5, "w": 6, "x": 6, "y": 0},
      "options": {"colorMode": "background", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "value_and_name"},
      "title": "% Cobertura Geral",
      "type": "stat",
      "targets": [{"rawSql": "SELECT ROUND(AVG(coverage)::numeric, 2) as \"Cobertura\" FROM sonar_project_metrics WHERE collected_at = (SELECT MAX(collected_at) FROM sonar_project_metrics)", "format": "table"}]
    },
    {
      "datasource": {"type": "postgres", "uid": ""},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "purple", "value": null}]}}, "overrides": []},
      "gridPos": {"h": 5, "w": 6, "x": 12, "y": 0},
      "options": {"colorMode": "background", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "value_and_name"},
      "title": "Total de Linhas Analisadas",
      "type": "stat",
      "targets": [{"rawSql": "SELECT SUM(ncloc) as \"Total linhas\" FROM sonar_project_metrics WHERE collected_at = (SELECT MAX(collected_at) FROM sonar_project_metrics)", "format": "table"}]
    },
    {
      "datasource": {"type": "postgres", "uid": ""},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "red", "value": null}]}}, "overrides": []},
      "gridPos": {"h": 5, "w": 6, "x": 18, "y": 0},
      "options": {"colorMode": "background", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "value_and_name"},
      "title": "Total Vulnerabilidades",
      "type": "stat",
      "targets": [{"rawSql": "SELECT SUM(vulnerabilities) as \"Vulnerabilidades\" FROM sonar_project_metrics WHERE collected_at = (SELECT MAX(collected_at) FROM sonar_project_metrics)", "format": "table"}]
    },
    {
      "datasource": {"type": "postgres", "uid": ""},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "orange", "value": null}]}}, "overrides": []},
      "gridPos": {"h": 5, "w": 6, "x": 0, "y": 5},
      "options": {"colorMode": "background", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "value_and_name"},
      "title": "Bugs em Aberto",
      "type": "stat",
      "targets": [{"rawSql": "SELECT SUM(bugs) as \"Bugs\" FROM sonar_project_metrics WHERE collected_at = (SELECT MAX(collected_at) FROM sonar_project_metrics)", "format": "table"}]
    },
    {
      "datasource": {"type": "postgres", "uid": ""},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "yellow", "value": null}]}}, "overrides": []},
      "gridPos": {"h": 5, "w": 6, "x": 6, "y": 5},
      "options": {"colorMode": "background", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "value_and_name"},
      "title": "Code Smells",
      "type": "stat",
      "targets": [{"rawSql": "SELECT SUM(code_smells) as \"Code Smells\" FROM sonar_project_metrics WHERE collected_at = (SELECT MAX(collected_at) FROM sonar_project_metrics)", "format": "table"}]
    },
    {
      "datasource": {"type": "postgres", "uid": ""},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "dark-red", "value": null}]}}, "overrides": []},
      "gridPos": {"h": 5, "w": 6, "x": 12, "y": 5},
      "options": {"colorMode": "background", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "value_and_name"},
      "title": "Security Hotspots",
      "type": "stat",
      "targets": [{"rawSql": "SELECT SUM(security_hotspots) as \"Security Hotspots\" FROM sonar_project_metrics WHERE collected_at = (SELECT MAX(collected_at) FROM sonar_project_metrics)", "format": "table"}]
    },
    {
      "datasource": {"type": "postgres", "uid": ""},
      "fieldConfig": {"defaults": {"color": {"mode": "thresholds"}, "thresholds": {"steps": [{"color": "semi-dark-green", "value": null}]}}, "overrides": []},
      "gridPos": {"h": 5, "w": 6, "x": 18, "y": 5},
      "options": {"colorMode": "background", "graphMode": "none", "justifyMode": "auto", "orientation": "auto", "reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": false}, "textMode": "value_and_name"},
      "title": "% Código Duplicado",
      "type": "stat",
      "targets": [{"rawSql": "SELECT ROUND(AVG(duplicated_lines_pct)::numeric, 2) as \"Duplicado %\" FROM sonar_project_metrics WHERE collected_at = (SELECT MAX(collected_at) FROM sonar_project_metrics)", "format": "table"}]
    },
    {
      "datasource": {"type": "postgres", "uid": ""},
      "fieldConfig": {"defaults": {}, "overrides": []},
      "gridPos": {"h": 8, "w": 24, "x": 0, "y": 10},
      "options": {},
      "title": "Evolução da Cobertura ao Longo do Tempo",
      "type": "timeseries",
      "targets": [{"rawSql": "SELECT collected_at as time, ROUND(AVG(coverage)::numeric, 2) as \"Cobertura %\" FROM sonar_project_metrics GROUP BY collected_at ORDER BY collected_at", "format": "time_series"}]
    },
    {
      "datasource": {"type": "postgres", "uid": ""},
      "fieldConfig": {"defaults": {}, "overrides": []},
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 18},
      "options": {},
      "title": "Projetos por Linha de Produto",
      "type": "table",
      "targets": [{"rawSql": "SELECT product_line as \"Linha de Produto\", COUNT(DISTINCT project_key) as \"Projetos\", ROUND(AVG(coverage)::numeric, 2) as \"Cobertura %\", SUM(vulnerabilities) as \"Vulnerabilidades\", SUM(bugs) as \"Bugs\" FROM sonar_project_metrics WHERE collected_at = (SELECT MAX(collected_at) FROM sonar_project_metrics) GROUP BY product_line ORDER BY \"Projetos\" DESC", "format": "table"}]
    },
    {
      "datasource": {"type": "postgres", "uid": ""},
      "fieldConfig": {"defaults": {}, "overrides": []},
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 18},
      "options": {},
      "title": "Issues por Severidade",
      "type": "table",
      "targets": [{"rawSql": "SELECT project_name as \"Projeto\", blocker_issues as \"Blocker\", critical_issues as \"Critical\", major_issues as \"Major\", minor_issues as \"Minor\", vulnerabilities as \"Vulnerabilities\" FROM sonar_project_metrics WHERE collected_at = (SELECT MAX(collected_at) FROM sonar_project_metrics) ORDER BY blocker_issues DESC, critical_issues DESC", "format": "table"}]
    }
  ],
  "schemaVersion": 39,
  "tags": ["sonarqube", "devsecops"],
  "templating": {"list": []},
  "time": {"from": "now-7d", "to": "now"},
  "title": "SonarQube - Painel Geral Senior",
  "uid": "sonar-painel-geral"
}
DASHBOARD

# ============================================================
# Script coletor de métricas (roda a cada 1 minuto via cron)
# ============================================================
cat > /opt/grafana/collect-metrics.py << 'PYTHON'
#!/usr/bin/env python3
"""Coletor de metricas SonarQube -> PostgreSQL (roda a cada 1 min)"""
import os, json, time, sys
from datetime import datetime
from urllib.request import Request, urlopen
from urllib.error import URLError

SONAR_URL = os.environ.get('SONAR_URL', 'http://SONAR_INTERNAL_IP:9000')
SONAR_TOKEN = os.environ.get('SONAR_TOKEN', 'TOKEN_PLACEHOLDER')
PG_CONN = os.environ.get('PG_CONN', 'host=localhost dbname=sonar_metrics user=grafana password=grafana123')

METRICS = 'coverage,duplicated_lines_density,bugs,vulnerabilities,code_smells,security_hotspots,blocker_violations,critical_violations,major_violations,minor_violations,ncloc,alert_status,security_rating,reliability_rating'

def sonar_get(path):
    import base64
    url = f"{SONAR_URL}{path}"
    creds = base64.b64encode(f"{SONAR_TOKEN}:".encode()).decode()
    req = Request(url, headers={'Authorization': f'Basic {creds}'})
    try:
        with urlopen(req, timeout=10) as resp:
            return json.loads(resp.read())
    except Exception as e:
        print(f"  ERRO API: {e}")
        return None

def get_projects():
    projects = []
    page = 1
    while True:
        data = sonar_get(f"/api/projects/search?ps=100&p={page}")
        if not data:
            break
        projects.extend(data.get('components', []))
        if page * 100 >= data.get('paging', {}).get('total', 0):
            break
        page += 1
    return projects

def get_metrics(project_key):
    data = sonar_get(f"/api/measures/component?component={project_key}&metricKeys={METRICS}")
    if not data:
        return {}
    metrics = {}
    for m in data.get('component', {}).get('measures', []):
        metrics[m['metric']] = m.get('value', '0')
    return metrics

def get_tags(project_key):
    data = sonar_get(f"/api/project_tags/search?project={project_key}")
    return data.get('tags', []) if data else []

def main():
    import psycopg2
    now = datetime.now()
    print(f"[{now}] Coletando metricas do SonarQube...")

    conn = psycopg2.connect(PG_CONN)
    cur = conn.cursor()

    projects = get_projects()
    print(f"  Projetos: {len(projects)}")

    for p in projects:
        key = p['key']
        name = p.get('name', key)
        metrics = get_metrics(key)
        if not metrics:
            continue

        tags = get_tags(key)
        product_line = ''
        module_name = ''
        for t in tags:
            if t in ('erp', 'hcm', 'logistica', 'arqptf', 'acesso'):
                product_line = t.upper()
            elif t.startswith('modulo-'):
                module_name = t.replace('modulo-', '')
            elif t == 'poc':
                product_line = product_line or 'POC'

        cur.execute("""
            INSERT INTO sonar_project_metrics 
            (project_key, project_name, product_line, module_name, coverage,
             duplicated_lines_pct, bugs, vulnerabilities, code_smells,
             security_hotspots, blocker_issues, critical_issues, major_issues,
             minor_issues, ncloc, quality_gate_status, security_rating,
             reliability_rating, collected_at)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (
            key, name, product_line, module_name,
            float(metrics.get('coverage', 0)),
            float(metrics.get('duplicated_lines_density', 0)),
            int(metrics.get('bugs', 0)),
            int(metrics.get('vulnerabilities', 0)),
            int(metrics.get('code_smells', 0)),
            int(metrics.get('security_hotspots', 0)),
            int(metrics.get('blocker_violations', 0)),
            int(metrics.get('critical_violations', 0)),
            int(metrics.get('major_violations', 0)),
            int(metrics.get('minor_violations', 0)),
            int(metrics.get('ncloc', 0)),
            metrics.get('alert_status', 'NONE'),
            metrics.get('security_rating', ''),
            metrics.get('reliability_rating', ''),
            now
        ))

    conn.commit()
    cur.close()
    conn.close()
    print(f"  Coleta finalizada: {len(projects)} projetos")

if __name__ == '__main__':
    main()
PYTHON

# Substituir placeholders
sed -i "s|SONAR_INTERNAL_IP|${sonar_url#http://}|g" /opt/grafana/collect-metrics.py
sed -i "s|http://SONAR_INTERNAL_IP:9000|SONAR_URL_PLACEHOLDER|g" /opt/grafana/collect-metrics.py
sed -i "s|TOKEN_PLACEHOLDER|SONAR_TOKEN_PLACEHOLDER|g" /opt/grafana/collect-metrics.py

# Instalar psycopg2
pip3 install psycopg2-binary

# Iniciar containers
cd /opt/grafana
docker-compose up -d

# Aguardar PostgreSQL ficar pronto
echo "Aguardando PostgreSQL..."
sleep 15

# Rodar primeira coleta
python3 /opt/grafana/collect-metrics.py || true

# Configurar cron para rodar a cada 1 minuto
cat > /etc/cron.d/sonar-metrics << 'CRON'
* * * * * root cd /opt/grafana && python3 /opt/grafana/collect-metrics.py >> /var/log/sonar-metrics.log 2>&1
CRON

chmod 644 /etc/cron.d/sonar-metrics
systemctl restart crond

echo "=== Grafana + Coletor configurados ==="
echo "Grafana: http://localhost:3000 (admin/admin123)"
echo "Coletor rodando a cada 1 minuto"

