# Infraestrutura POC DevSecOps Pipeline - Senior
# Profile: laurence-poc-dati
# Região: us-east-1

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# ============================================================
# VPC e Networking (simplificado para POC)
# ============================================================
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group para aplicação e SonarQube
resource "aws_security_group" "poc_devsecops" {
  name        = "poc-devsecops-sg"
  description = "SG para POC DevSecOps - App, SonarQube, Grafana"
  vpc_id      = data.aws_vpc.default.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # App Node.js
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SonarQube
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # PostgreSQL (Grafana backend)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MySQL (RDS)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "poc-devsecops-sg"
    Environment = "poc"
    Project     = "senior-devsecops"
  }
}

# ============================================================
# EC2 - SonarQube + Grafana + PostgreSQL (tudo na mesma instância)
# ============================================================
resource "aws_instance" "sonarqube" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.large" # 2 vCPU, 8GB RAM - mínimo para SonarQube
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.poc_devsecops.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/userdata-sonarqube.sh", {
    sonar_db_pass = var.sonar_db_password
  })

  tags = {
    Name        = "poc-staging-sonarqube"
    Environment = "staging"
    Project     = "senior-devsecops"
    Role        = "sonarqube"
  }
}

# ============================================================
# EC2 - Aplicação Node.js (staging)
# ============================================================
resource "aws_instance" "app_staging" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.poc_devsecops.id]

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/userdata-app.sh", {
    db_host = aws_db_instance.staging.address
    db_user = var.db_username
    db_pass = var.db_password
    db_name = var.db_name
  })

  tags = {
    Name        = "poc-staging-app"
    Environment = "staging"
    Project     = "senior-devsecops"
    Role        = "application"
  }

  depends_on = [aws_db_instance.staging]
}

# ============================================================
# EC2 - Aplicação Node.js (prod)
# ============================================================
resource "aws_instance" "app_prod" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.poc_devsecops.id]

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/userdata-app.sh", {
    db_host = aws_db_instance.prod.address
    db_user = var.db_username
    db_pass = var.db_password
    db_name = var.db_name
  })

  tags = {
    Name        = "poc-prod-app"
    Environment = "prod"
    Project     = "senior-devsecops"
    Role        = "application"
  }

  depends_on = [aws_db_instance.prod]
}

# ============================================================
# RDS MySQL - Staging
# ============================================================
resource "aws_db_instance" "staging" {
  identifier             = "poc-staging-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.poc_devsecops.id]
  skip_final_snapshot    = true
  publicly_accessible    = true

  tags = {
    Name        = "poc-staging-mysql"
    Environment = "staging"
    Project     = "senior-devsecops"
  }
}

# ============================================================
# RDS MySQL - Prod
# ============================================================
resource "aws_db_instance" "prod" {
  identifier             = "poc-prod-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.poc_devsecops.id]
  skip_final_snapshot    = true
  publicly_accessible    = true

  tags = {
    Name        = "poc-prod-mysql"
    Environment = "prod"
    Project     = "senior-devsecops"
  }
}

# ============================================================
# AMI Amazon Linux 2023
# ============================================================
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
