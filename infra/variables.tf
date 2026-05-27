variable "region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Profile AWS CLI"
  type        = string
  default     = "laurence-poc-dati"
}

variable "key_pair_name" {
  description = "Nome do key pair para acesso SSH às EC2"
  type        = string
}

variable "db_username" {
  description = "Usuário do banco MySQL"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Senha do banco MySQL"
  type        = string
  default     = "Administrator-123"
  sensitive   = true
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "erp_pessoas"
}

variable "sonar_db_password" {
  description = "Senha do PostgreSQL interno do SonarQube"
  type        = string
  default     = "sonar123"
  sensitive   = true
}

variable "github_repo" {
  description = "URL do repositório GitHub para o CodeBuild"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "Token do GitHub para CodeBuild (Personal Access Token)"
  type        = string
  default     = ""
  sensitive   = true
}
