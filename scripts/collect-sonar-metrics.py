#!/usr/bin/env python3
"""
Script de coleta de métricas do SonarQube → PostgreSQL
Reproduz o fluxo da Senior: extração via API toda madrugada,
consolidação em base PostgreSQL para alimentar dashboards Grafana.

Métricas coletadas:
- Coverage, duplicated lines, bugs, vulnerabilities, code smells
- Security hotspots, blocker/critical/major/minor issues
- Quality gate status, ncloc (lines of code)

Agrupamento por tags: Linha de Produto e Módulo
"""

import os
import sys
import json
import time
import requests
import psycopg2
from datetime import datetime

# Configuração do SonarQube
SONAR_URL = os.environ.get('SONAR_URL', 'http://localhost:9000')
SONAR_TOKEN = os.environ.get('SONAR_TOKEN', '')

# Configuração do PostgreSQL (Grafana backend)
PG_HOST = os.environ.get('PG_HOST', 'localhost')
PG_PORT = os.environ.get('PG_PORT', '5432')
PG_DB = os.environ.get('PG_DB', 'sonar_metrics')
PG_USER = os.environ.get('PG_USER', 'grafana')
PG_PASS = os.environ.get('PG_PASS', 'grafana123')

# Métricas a coletar (mesmas que a Senior extrai)
METRICS = [
    'coverage',
    'duplicated_lines_density',
    'bugs',
    'vulnerabilities',
    'code_smells',
    'security_hotspots',
    'blocker_violations',
    'critical_violations',
    'major_violations',
    'minor_violations',
    'ncloc',
    'alert_status'  # Quality Gate status
]


def get_sonar_projects():
    """Busca todos os projetos do SonarQube via API"""
    projects = []
    page = 1
    page_size = 100

    while True:
        url = f"{SONAR_URL}/api/projects/search?ps={page_size}&p={page}"
        response = requests.get(url, auth=(SONAR_TOKEN, ''))
        response.raise_for_status()
        data = response.json()

        projects.extend(data['components'])

        if page * page_size >= data['paging']['total']:
            break
        page += 1

    return projects


def get_project_metrics(project_key):
    """Busca métricas de um projeto específico"""
    metric_keys = ','.join(METRICS)
    url = f"{SONAR_URL}/api/measures/component?component={project_key}&metricKeys={metric_keys}"
    response = requests.get(url, auth=(SONAR_TOKEN, ''))
    response.raise_for_status()
    data = response.json()

    metrics = {}
    for measure in data.get('component', {}).get('measures', []):
        metrics[measure['metric']] = measure.get('value', '0')

    return metrics


def get_project_tags(project_key):
    """Busca tags do projeto (Linha de Produto e Módulo)"""
    url = f"{SONAR_URL}/api/project_tags/search?project={project_key}"
    try:
        response = requests.get(url, auth=(SONAR_TOKEN, ''))
        response.raise_for_status()
        return response.json().get('tags', [])
    except Exception:
        return []


def parse_tags(tags):
    """Extrai Linha de Produto e Módulo das tags (padrão Senior)"""
    product_line = ''
    module_name = ''

    for tag in tags:
        # Convenção Senior: tags como "erp", "hcm", "logistica" para linha de produto
        # e tags como "modulo-financas", "modulo-rh" para módulo
        if tag.startswith('modulo-'):
            module_name = tag.replace('modulo-', '')
        elif tag in ['erp', 'hcm', 'logistica', 'arqptf', 'acesso', 'poc']:
            product_line = tag.upper()

    return product_line, module_name


def save_to_postgres(conn, project_data):
    """Salva métricas no PostgreSQL"""
    cursor = conn.cursor()

    insert_sql = """
        INSERT INTO sonar_project_metrics 
        (project_key, project_name, product_line, module_name, coverage, 
         duplicated_lines_pct, bugs, vulnerabilities, code_smells, 
         security_hotspots, blocker_issues, critical_issues, major_issues, 
         minor_issues, ncloc, quality_gate_status, collected_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """

    cursor.execute(insert_sql, (
        project_data['project_key'],
        project_data['project_name'],
        project_data['product_line'],
        project_data['module_name'],
        project_data.get('coverage', 0),
        project_data.get('duplicated_lines_density', 0),
        project_data.get('bugs', 0),
        project_data.get('vulnerabilities', 0),
        project_data.get('code_smells', 0),
        project_data.get('security_hotspots', 0),
        project_data.get('blocker_violations', 0),
        project_data.get('critical_violations', 0),
        project_data.get('major_violations', 0),
        project_data.get('minor_violations', 0),
        project_data.get('ncloc', 0),
        project_data.get('alert_status', 'NONE'),
        datetime.now()
    ))

    conn.commit()
    cursor.close()


def main():
    print(f"[{datetime.now()}] Iniciando coleta de métricas do SonarQube")
    print(f"  SonarQube URL: {SONAR_URL}")
    print(f"  PostgreSQL: {PG_HOST}:{PG_PORT}/{PG_DB}")

    # Conectar ao PostgreSQL
    conn = psycopg2.connect(
        host=PG_HOST,
        port=PG_PORT,
        database=PG_DB,
        user=PG_USER,
        password=PG_PASS
    )

    # Buscar projetos
    projects = get_sonar_projects()
    print(f"  Projetos encontrados: {len(projects)}")

    collected = 0
    errors = 0

    for project in projects:
        try:
            project_key = project['key']
            project_name = project.get('name', project_key)

            # Buscar métricas
            metrics = get_project_metrics(project_key)

            # Buscar tags para agrupamento
            tags = get_project_tags(project_key)
            product_line, module_name = parse_tags(tags)

            # Consolidar dados
            project_data = {
                'project_key': project_key,
                'project_name': project_name,
                'product_line': product_line,
                'module_name': module_name,
                **metrics
            }

            # Salvar no PostgreSQL
            save_to_postgres(conn, project_data)
            collected += 1

        except Exception as e:
            print(f"  ERRO ao coletar {project.get('key', '?')}: {e}")
            errors += 1

    conn.close()
    print(f"[{datetime.now()}] Coleta finalizada: {collected} projetos coletados, {errors} erros")


if __name__ == '__main__':
    main()
