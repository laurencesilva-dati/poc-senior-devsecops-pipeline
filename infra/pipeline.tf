# ============================================================
# Esteira DevSecOps: CodePipeline + CodeBuild + CodeDeploy
# ============================================================

# IAM Role para CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "poc-devsecops-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "poc-devsecops-codebuild-role"
    Environment = "poc"
    Project     = "senior-devsecops"
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "poc-devsecops-codebuild-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role para CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "poc-devsecops-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "poc-devsecops-codepipeline-role"
    Environment = "poc"
    Project     = "senior-devsecops"
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "poc-devsecops-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
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
      Principal = {
        Service = "codedeploy.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "poc-devsecops-codedeploy-role"
    Environment = "poc"
    Project     = "senior-devsecops"
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# IAM Instance Profile para EC2 (CodeDeploy Agent)
resource "aws_iam_role" "ec2_codedeploy_role" {
  name = "poc-devsecops-ec2-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
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

# S3 Bucket para artefatos do Pipeline
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "poc-devsecops-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "poc-devsecops-artifacts"
    Environment = "poc"
    Project     = "senior-devsecops"
  }
}

data "aws_caller_identity" "current" {}

# Secrets Manager - Token do SonarQube
resource "aws_secretsmanager_secret" "sonar_token" {
  name                    = "poc-devsecops/sonarqube"
  recovery_window_in_days = 0

  tags = {
    Name        = "poc-devsecops-sonar-token"
    Environment = "poc"
    Project     = "senior-devsecops"
  }
}

resource "aws_secretsmanager_secret_version" "sonar_token" {
  secret_id = aws_secretsmanager_secret.sonar_token.id
  secret_string = jsonencode({
    token = "sqa_e69e1691948b7506aae4adfc70853f90c612c79c"
    url   = "http://${aws_instance.sonarqube.private_ip}:9000"
  })
}

# CodeStar Connection para GitHub
resource "aws_codestarconnections_connection" "github" {
  name          = "poc-devsecops-github"
  provider_type = "GitHub"

  tags = {
    Name        = "poc-devsecops-github-connection"
    Environment = "poc"
    Project     = "senior-devsecops"
  }
}

# ============================================================
# CodeBuild - Security Scan (SAST + SCA + Secrets + IaC)
# ============================================================
resource "aws_codebuild_project" "security_scan" {
  name          = "poc-devsecops-security-scan"
  description   = "Pipeline DevSecOps - SAST (SonarQube) + SCA (Trivy) + Secrets (TruffleHog) + IaC Scan"
  build_timeout = 30
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "SONAR_HOST_URL"
      value = "http://${aws_instance.sonarqube.private_ip}:9000"
    }

    environment_variable {
      name  = "SONAR_TOKEN"
      value = "poc-devsecops/sonarqube:token"
      type  = "SECRETS_MANAGER"
    }

    environment_variable {
      name  = "SONAR_PROJECT_KEY"
      value = "poc-erp-gestao-pessoas"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/poc-devsecops"
      stream_name = "security-scan"
    }
  }

  tags = {
    Name        = "poc-devsecops-security-scan"
    Environment = "poc"
    Project     = "senior-devsecops"
  }
}

# ============================================================
# CodeDeploy - Application
# ============================================================
resource "aws_codedeploy_app" "app" {
  name             = "poc-devsecops-app"
  compute_platform = "Server"
}

# Deployment Group - Staging
resource "aws_codedeploy_deployment_group" "staging" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "poc-staging"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Environment"
      type  = "KEY_AND_VALUE"
      value = "staging"
    }
    ec2_tag_filter {
      key   = "Role"
      type  = "KEY_AND_VALUE"
      value = "application"
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

# Deployment Group - Prod
resource "aws_codedeploy_deployment_group" "prod" {
  app_name              = aws_codedeploy_app.app.name
  deployment_group_name = "poc-prod"
  service_role_arn      = aws_iam_role.codedeploy_role.arn

  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Environment"
      type  = "KEY_AND_VALUE"
      value = "prod"
    }
    ec2_tag_filter {
      key   = "Role"
      type  = "KEY_AND_VALUE"
      value = "application"
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

# ============================================================
# CodePipeline - Esteira completa
# ============================================================
resource "aws_codepipeline" "devsecops" {
  name     = "poc-devsecops-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  # Stage 1: Source (GitHub)
  stage {
    name = "Source"

    action {
      name             = "GitHub_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "laurencesilva-dati/poc-senior-devsecops-pipeline"
        BranchName       = "main"
      }
    }
  }

  # Stage 2: Security Scan (SAST + SCA + Secrets + IaC + Tests)
  stage {
    name = "SecurityScan"

    action {
      name             = "SAST_SCA_Scan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.security_scan.name
      }
    }
  }

  # Stage 3: Deploy Staging
  stage {
    name = "Deploy_Staging"

    action {
      name            = "Deploy_to_Staging"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.staging.deployment_group_name
      }
    }
  }

  # Stage 4: Aprovação manual para Prod
  stage {
    name = "Approval"

    action {
      name     = "Manual_Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        CustomData = "Security scan passou. Aprovar deploy para producao?"
      }
    }
  }

  # Stage 5: Deploy Prod
  stage {
    name = "Deploy_Prod"

    action {
      name            = "Deploy_to_Prod"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.prod.deployment_group_name
      }
    }
  }

  tags = {
    Name        = "poc-devsecops-pipeline"
    Environment = "poc"
    Project     = "senior-devsecops"
  }
}
