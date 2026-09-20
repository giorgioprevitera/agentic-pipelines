# =============================================================================
# OIDC Bootstrap — run this ONCE locally before any pipeline runs
# terraform -chdir=infra/bootstrap init && apply
#
# What this creates:
#   - GitHub OIDC provider in your AWS account
#   - IAM role for the infra pipeline  (can run Terraform)
#   - IAM role for the build pipeline  (can push to ECR)
#   - IAM role for the deploy pipeline (can update ECS)
# =============================================================================

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # After first apply, move this state to S3 too — for now local is fine
  # because bootstrap only runs once.
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# GitHub OIDC Provider
# -----------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint (stable — GitHub rotates the cert but AWS
  # validates audience, not thumbprint, for GitHub's OIDC endpoint)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# -----------------------------------------------------------------------------
# Shared trust policy factory
# -----------------------------------------------------------------------------
locals {
  # New GitHub repos use an "immutable" OIDC subject that embeds numeric IDs,
  # e.g. repo:owner@123/name@456:ref:refs/heads/main. Set github_sub_prefix to
  # the value of `sub_claim_prefix` from:
  #   gh api repos/<org>/<repo>/actions/oidc/customization/sub
  # Leave it empty for older repos using the name-based subject.
  sub_prefix = var.github_sub_prefix != "" ? var.github_sub_prefix : "repo:${var.github_org}/${var.github_repo}"
}

data "aws_iam_policy_document" "github_trust" {
  for_each = {
    infra  = "ref:refs/heads/main" # infra pipeline: main branch only
    build  = "*"                   # build pipeline: any ref (PRs need ECR push too)
    deploy = "ref:refs/heads/main" # deploy pipeline: main branch only
  }

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # e.g. repo:my-org/my-repo:ref:refs/heads/main
      #  or  repo:my-org@123/my-repo@456:ref:refs/heads/main (immutable subject)
      values = ["${local.sub_prefix}:${each.value}"]
    }
  }
}

# -----------------------------------------------------------------------------
# Role: infra-pipeline
# Permissions: full Terraform access (S3 state, DynamoDB lock + your infra)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "infra_pipeline" {
  name               = "${var.project}-infra-pipeline"
  assume_role_policy = data.aws_iam_policy_document.github_trust["infra"].json
}

resource "aws_iam_role_policy_attachment" "infra_pipeline_admin" {
  role = aws_iam_role.infra_pipeline.name
  # TODO: replace with a scoped policy once you know exactly what Terraform needs
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# -----------------------------------------------------------------------------
# Role: build-pipeline
# Permissions: ECR push only
# -----------------------------------------------------------------------------
resource "aws_iam_role" "build_pipeline" {
  name               = "${var.project}-build-pipeline"
  assume_role_policy = data.aws_iam_policy_document.github_trust["build"].json
}

data "aws_iam_policy_document" "ecr_push" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    # Scoped to your project's ECR repo — ARN comes from main infra outputs
    resources = ["arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${var.project}"]
  }
}

resource "aws_iam_role_policy" "build_pipeline_ecr" {
  name   = "ecr-push"
  role   = aws_iam_role.build_pipeline.name
  policy = data.aws_iam_policy_document.ecr_push.json
}

# -----------------------------------------------------------------------------
# Role: deploy-pipeline
# Permissions: register ECS task definitions + update ECS services
# -----------------------------------------------------------------------------
resource "aws_iam_role" "deploy_pipeline" {
  name               = "${var.project}-deploy-pipeline"
  assume_role_policy = data.aws_iam_policy_document.github_trust["deploy"].json
}

data "aws_iam_policy_document" "ecs_deploy" {
  statement {
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeClusters",
    ]
    resources = ["*"]
  }

  statement {
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${var.aws_account_id}:role/${var.project}-ecs-task-execution",
      "arn:aws:iam::${var.aws_account_id}:role/${var.project}-ecs-task",
    ]
  }

  # Needed for the deploy pipeline to read CloudWatch logs on failure
  statement {
    effect = "Allow"
    actions = [
      "logs:GetLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:FilterLogEvents",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/ecs/${var.project}*"]
  }
}

resource "aws_iam_role_policy" "deploy_pipeline_ecs" {
  name   = "ecs-deploy"
  role   = aws_iam_role.deploy_pipeline.name
  policy = data.aws_iam_policy_document.ecs_deploy.json
}
