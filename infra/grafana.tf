# ============================================================
# EC2 dedicada para Grafana + PostgreSQL + Coletor de métricas
# ============================================================

resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.poc_devsecops.id]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = <<-USERDATA
#!/bin/bash
set -e
yum update -y
yum install -y docker git python3 python3-pip
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
pip3 install psycopg2-binary
mkdir -p /opt/grafana && cd /opt/grafana
# Baixar setup do repositorio
curl -sSL "https://raw.githubusercontent.com/laurencesilva-dati/poc-senior-devsecops-pipeline/main/scripts/grafana-setup.sh" -o setup.sh
export SONAR_URL="http://${aws_instance.sonarqube.private_ip}:9000"
export SONAR_TOKEN="sqa_dcfc4da158d428310321efdeca2e495a4262001b"
bash setup.sh
USERDATA

  tags = {
    Name        = "poc-staging-grafana"
    Environment = "staging"
    Project     = "senior-devsecops"
    Role        = "grafana"
  }
}

output "grafana_dedicated_url" {
  description = "URL do Grafana dedicado"
  value       = "http://${aws_instance.grafana.public_ip}:3000"
}
