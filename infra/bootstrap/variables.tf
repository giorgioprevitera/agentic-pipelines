variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "aws_account_id" {
  description = "Your 12-digit AWS account ID"
  type        = string
}

variable "github_org" {
  description = "GitHub org or username (e.g. my-org)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. agentic-pipelines)"
  type        = string
}

variable "github_sub_prefix" {
  description = "OIDC subject prefix; use sub_claim_prefix from `gh api repos/<org>/<repo>/actions/oidc/customization/sub`. Empty = repo:<org>/<repo>"
  type        = string
  default     = ""
}

variable "project" {
  description = "Short project name used as a prefix for all resources"
  type        = string
  default     = "agentic-pipelines"
}
