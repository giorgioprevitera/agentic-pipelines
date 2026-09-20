output "oidc_provider_arn" {
  description = "Copy this into your main infra if needed"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "infra_pipeline_role_arn" {
  description = "Set as GH secret: AWS_ROLE_INFRA"
  value       = aws_iam_role.infra_pipeline.arn
}

output "build_pipeline_role_arn" {
  description = "Set as GH secret: AWS_ROLE_BUILD"
  value       = aws_iam_role.build_pipeline.arn
}

output "deploy_pipeline_role_arn" {
  description = "Set as GH secret: AWS_ROLE_DEPLOY"
  value       = aws_iam_role.deploy_pipeline.arn
}
