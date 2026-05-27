#!/bin/bash
# Setup Grafana + PostgreSQL + Coletor de metricas do SonarQube
# Variaveis esperadas: SONAR_URL, SONAR_TOKEN
set -e
cd /opt/grafana

cat > docker-compose.yml << 'EOF'
version: "3.8"
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
    volumes:
      - grafana_data:/var/lib/grafana
      - ./provisioning:/etc/grafana/provisioning
    restart: unless-stopped
volumes:
  pg_data:
  grafana_data:
EOF

cat > init-db.sql << 'EOF'
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
  collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_collected_at ON sonar_project_metrics(collected_at);
CREATE INDEX IF NOT EXISTS idx_project_key ON sonar_project_metrics(project_key);
EOF

mkdir -p provisioning/datasources
cat > provisioning/datasources/postgres.yml << 'EOF'
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
EOF

# Coletor de metricas
cat > collect-metrics.py << PYEOF
#!/usr/bin/env python3
import os, json, base64, sys
from datetime import datetime
from urllib.request import Request, urlopen
import psycopg2

SONAR_URL = os.environ.get("SONAR_URL", "${SONAR_URL}")
SONAR_TOKEN = os.environ.get("SONAR_TOKEN", "${SONAR_TOKEN}")
METRICS = "coverage,duplicated_lines_density,bugs,vulnerabilities,code_smells,security_hotspots,blocker_violations,critical_violations,major_violations,minor_violations,ncloc,alert_status"

def api(path):
    creds = base64.b64encode(f"{SONAR_TOKEN}:".encode()).decode()
    req = Request(f"{SONAR_URL}{path}", headers={"Authorization": f"Basic {creds}"})
    try:
        with urlopen(req, timeout=10) as r:
            return json.loads(r.read())
    except Exception as e:
        print(f"ERR: {e}")
        return None

now = datetime.now()
print(f"[{now}] Coletando...")
conn = psycopg2.connect("host=localhost dbname=sonar_metrics user=grafana password=grafana123")
cur = conn.cursor()
data = api("/api/projects/search?ps=100")
if not data:
    sys.exit(1)
for p in data.get("components", []):
    key = p["key"]
    m = api(f"/api/measures/component?component={key}&metricKeys={METRICS}")
    if not m:
        continue
    vals = {x["metric"]: x.get("value", "0") for x in m.get("component", {}).get("measures", [])}
    cur.execute(
        "INSERT INTO sonar_project_metrics (project_key,project_name,coverage,duplicated_lines_pct,bugs,vulnerabilities,code_smells,security_hotspots,blocker_issues,critical_issues,major_issues,minor_issues,ncloc,quality_gate_status,collected_at) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
        (key, p.get("name",key), float(vals.get("coverage",0)), float(vals.get("duplicated_lines_density",0)),
         int(vals.get("bugs",0)), int(vals.get("vulnerabilities",0)), int(vals.get("code_smells",0)),
         int(vals.get("security_hotspots",0)), int(vals.get("blocker_violations",0)),
         int(vals.get("critical_violations",0)), int(vals.get("major_violations",0)),
         int(vals.get("minor_violations",0)), int(vals.get("ncloc",0)), vals.get("alert_status","NONE"), now))
conn.commit()
cur.close()
conn.close()
print(f"  OK: {len(data.get('components',[]))} projetos")
PYEOF

docker-compose up -d
echo "Aguardando PostgreSQL..."
sleep 15
python3 /opt/grafana/collect-metrics.py || true

# Cron a cada 1 minuto
echo "* * * * * root cd /opt/grafana && python3 collect-metrics.py >> /var/log/sonar-metrics.log 2>&1" > /etc/cron.d/sonar-metrics
chmod 644 /etc/cron.d/sonar-metrics
systemctl restart crond
echo "=== Grafana pronto: http://localhost:3000 (admin/admin123) ==="
