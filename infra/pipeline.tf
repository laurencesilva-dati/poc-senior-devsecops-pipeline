# ============================================================
# NOVA ARQUITETURA DE PIPELINES DevSecOps
# ============================================================
# 1. poc-devsecops-scan       → Push em dev → SonarQube scan
# 2. poc-devsecops-pr-validation → PR para staging/prod → Consulta API → Bloqueia/Libera
# 3. poc-devsecops-deploy-staging → Push em staging → Deploy
# 4. poc-devsecops-deploy-prod    → Push em prod → Deploy
# ============================================================

# IAM Role para CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "poc-devsecops-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })

  tags = { Name = "poc-devsecops-codebuild-role", Project = "senior-devsecops" }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "poc-devsecops-codebuild-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:*"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["codedeploy:*"]
        Resource = "*"
      }
    ]
  })
}

# IAM Role para CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "poc-devsecops-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
    }]
  })

  tags = { Name = "poc-devsecops-codedeploy-role", Project = "senior-devsecops" }
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# IAM para EC2 (CodeDeploy Agent)
resource "aws_iam_role" "ec2_codedeploy_role" {
  name = "poc-devsecops-ec2-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_codedeploy" {
  role       = aws_iam_role.ec2_codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_codedeploy" {
  name = "poc-devsecops-ec2-profile"
  role = aws_iam_role.ec2_codedeploy_role.name
}

# S3 para artefatos
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "poc-devsecops-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = { Name = "poc-devsecops-artifacts", Project = "senior-devsecops" }
}

data "aws_caller_identity" "current" {}

# ============================================================
# 1. CodeBuild: SCAN (push em dev)
# ============================================================
resource "aws_codebuild_project" "scan" {
  name          = "poc-devsecops-scan"
  description   = "Scan de codigo: push em dev -> SonarQube + Trivy"
  build_timeout = 20
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts { type = "NO_ARTIFACTS" }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "SONAR_HOST_URL"
      value = "http://${aws_instance.sonarqube.public_ip}:9000"
    }
    environment_variable {
      name  = "SONAR_TOKEN"
      value = "sqa_dcfc4da158d428310321efdeca2e495a4262001b"
    }
    environment_variable {
      name  = "SONAR_PROJECT_KEY"
      value = "poc-erp-gestao-pessoas"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/laurencesilva-dati/poc-senior-devsecops-pipeline.git"
    buildspec       = "buildspec-scan.yml"
    git_clone_depth = 1
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/poc-devsecops"
      stream_name = "scan"
    }
  }

  tags = { Name = "poc-devsecops-scan", Project = "senior-devsecops" }
}

# Webhook: push em dev
resource "aws_codebuild_webhook" "scan_webhook" {
  project_name = aws_codebuild_project.scan.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
    filter {
      type    = "HEAD_REF"
      pattern = "^refs/heads/dev$"
    }
  }
}

# ============================================================
# 2. CodeBuild: PR VALIDATION (PR para staging ou prod)
# ============================================================
resource "aws_codebuild_project" "pr_validation" {
  name          = "poc-devsecops-pr-validation"
  description   = "Valida PR: consulta SonarQube API e reporta status no GitHub"
  build_timeout = 10
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts { type = "NO_ARTIFACTS" }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "SONAR_HOST_URL"
      value = "http://${aws_instance.sonarqube.public_ip}:9000"
    }
    environment_variable {
      name  = "SONAR_TOKEN"
      value = "sqa_dcfc4da158d428310321efdeca2e495a4262001b"
    }
    environment_variable {
      name  = "SONAR_PROJECT_KEY"
      value = "poc-erp-gestao-pessoas"
    }
    environment_variable {
      name  = "GITHUB_TOKEN"
      value = var.github_token
    }
    environment_variable {
      name  = "GITHUB_REPO"
      value = "laurencesilva-dati/poc-senior-devsecops-pipeline"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/laurencesilva-dati/poc-senior-devsecops-pipeline.git"
    buildspec       = "buildspec-pr.yml"
    git_clone_depth = 1
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/poc-devsecops"
      stream_name = "pr-validation"
    }
  }

  tags = { Name = "poc-devsecops-pr-validation", Project = "senior-devsecops" }
}

# Webhook: PR para staging ou prod
resource "aws_codebuild_webhook" "pr_webhook" {
  project_name = aws_codebuild_project.pr_validation.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PULL_REQUEST_CREATED,PULL_REQUEST_UPDATED,PULL_REQUEST_REOPENED"
    }
    filter {
      type    = "BASE_REF"
      pattern = "^refs/heads/(staging|prod)$"
    }
  }
}

# ============================================================
# 3. CodeDeploy
# ============================================================
resource "aws_codedeploy_app" "app" {
  name             = "poc-devsecops-app"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "staging" {
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "poc-staging"
  service_role_arn       = aws_iam_role.codedeploy_role.arn
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "poc-staging-app"
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

resource "aws_codedeploy_deployment_group" "prod" {
  app_name               = aws_codedeploy_app.app.name
  deployment_group_name  = "poc-prod"
  service_role_arn       = aws_iam_role.codedeploy_role.arn
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "poc-prod-app"
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}
