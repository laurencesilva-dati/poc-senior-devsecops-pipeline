# POC DevSecOps Pipeline - Senior

## Objetivo

Reproduzir o ambiente de DevSecOps da Senior para entender como funciona a esteira de análise de código, dashboards de métricas e bloqueio de MR/PR com base em Quality Gates.

## Arquitetura

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        DEVELOPER WORKFLOW                                │
├─────────────────────────────────────────────────────────────────────────┤
│  Código (Node.js) → Tags (produto/módulo) → Push/PR no GitHub           │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    CI PIPELINE (AWS CodeBuild)                           │
├─────────────────────────────────────────────────────────────────────────┤
│  Stage 1: Security Scans                                                │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐          │
│  │ SAST       │ │ SCA        │ │ Secrets    │ │ IaC Scan   │          │
│  │ SonarQube  │ │ Trivy      │ │ TruffleHog │ │ Trivy      │          │
│  └────────────┘ └────────────┘ └────────────┘ └────────────┘          │
│                                                                         │
│  Stage 2: Unit Tests + Coverage (Jest)                                  │
│                                                                         │
│  Stage 3: Quality Gate Check (SonarQube API)                            │
│  → Se FAILED: bloqueia merge/deploy                                     │
│  → Se PASSED: prossegue para deploy                                     │
│                                                                         │
│  Stage 4: Deploy (staging ou prod)                                      │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    OBSERVABILIDADE & GESTÃO                              │
├─────────────────────────────────────────────────────────────────────────┤
│  SonarQube (SAST + Coverage + Quality Gate)                             │
│       ↓ API (extração noturna)                                          │
│  PostgreSQL (métricas consolidadas)                                     │
│       ↓                                                                 │
│  Grafana (dashboards: Geral, Linha de Produto, Módulo, Vulnerabilidades)│
└─────────────────────────────────────────────────────────────────────────┘
```

## Infraestrutura (Terraform)

| Recurso | Nome | Propósito |
|---------|------|-----------|
| EC2 t3.large | poc-staging-sonarqube | SonarQube + Grafana + PostgreSQL (Docker) |
| EC2 t3.micro | poc-staging-app | Aplicação Node.js (staging) |
| EC2 t3.micro | poc-prod-app | Aplicação Node.js (prod) |
| RDS db.t3.micro | poc-staging-mysql | MySQL para app (staging) |
| RDS db.t3.micro | poc-prod-mysql | MySQL para app (prod) |

## Aplicação (propositalmente vulnerável)

ERP de Gestão de Pessoas com:
- Gestão de usuários (CRUD)
- Gestão de departamentos
- Agendamento de férias

**Vulnerabilidades intencionais:**
- SQL Injection (concatenação direta de input)
- XSS (output não sanitizado)
- Credenciais hardcoded (senha do banco, JWT secret)
- Hash fraco (MD5 para senhas)
- IDOR (sem verificação de permissão)
- Exposição de stack trace
- Criptografia fraca
- Falta de rate limiting
- Falta de CSRF protection

## Como usar

### 1. Provisionar infraestrutura
```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars com seus valores
terraform init
terraform plan
terraform apply
```

### 2. Acessar SonarQube
- URL: http://<sonarqube-ip>:9000
- Login: admin / admin (trocar na primeira vez)
- Criar token de acesso para o CodeBuild

### 3. Configurar Quality Gate (reproduzir Senior)
No SonarQube, criar Quality Gate com:
- Security Hotspots Reviewed < 100% → FAIL
- Coverage < 80% → FAIL
- Duplicated Lines > 3% → FAIL
- Maintainability Rating worse than A → FAIL
- Blocker Issues > 0 → FAIL
- Critical Issues > 0 → FAIL
- Major Issues > 0 → FAIL
- Vulnerabilities > 0 → FAIL
- Reliability Rating worse than A → FAIL
- Security Rating worse than A → FAIL

### 4. Executar pipeline
O CodeBuild é trigado por push/PR no GitHub e executa:
1. SAST (SonarQube Scanner)
2. SCA (Trivy filesystem)
3. Secret Detection (TruffleHog)
4. IaC Scan (Trivy config)
5. Unit Tests + Coverage (Jest)
6. Quality Gate Check (SonarQube API)
7. Deploy (se Quality Gate passou)

### 5. Coletar métricas (cron noturno)
```bash
cd scripts
pip install requests psycopg2-binary
python3 collect-sonar-metrics.py
```

### 6. Acessar Grafana
- URL: http://<sonarqube-ip>:3001
- Login: admin / admin123
- Datasource: PostgreSQL (sonar_metrics)
