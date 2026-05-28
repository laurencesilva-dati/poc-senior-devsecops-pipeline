# ============================================================
# CodeBuild para validação de PRs (Quality Gate → GitHub Status)
# Trigado por webhook quando PR é aberta para branch "prod"
# ============================================================

resource "aws_codebuild_project" "pr_validation" {
  name          = "poc-devsecops-pr-validation"
  description   = "Valida PRs para prod: SonarQube scan + Quality Gate + GitHub Status Check"
  build_timeout = 15
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "SONAR_HOST_URL"
      value = "http://${aws_instance.sonarqube.public_ip}:9000"
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "SONAR_TOKEN"
      value = "sqa_dcfc4da158d428310321efdeca2e495a4262001b"
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "SONAR_PROJECT_KEY"
      value = "poc-erp-gestao-pessoas"
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "GITHUB_TOKEN"
      value = var.github_token
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "GITHUB_REPO"
      value = "laurencesilva-dati/poc-senior-devsecops-pipeline"
      type  = "PLAINTEXT"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/laurencesilva-dati/poc-senior-devsecops-pipeline.git"
    buildspec       = "buildspec-pr.yml"
    git_clone_depth = 1
    report_build_status = true
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/poc-devsecops"
      stream_name = "pr-validation"
    }
  }

  tags = {
    Name        = "poc-devsecops-pr-validation"
    Environment = "poc"
    Project     = "senior-devsecops"
  }
}

# Webhook: dispara build quando PR é aberta/atualizada para branch "prod"
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
      pattern = "^refs/heads/prod$"
    }
  }
}
