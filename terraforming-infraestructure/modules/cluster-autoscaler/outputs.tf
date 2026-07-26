output "iam_role_arn" {
  description = "ARN da role IAM usada pelo Cluster Autoscaler via Pod Identity."
  value       = aws_iam_role.this.arn
}

output "helm_release_name" {
  description = "Nome da release Helm do Cluster Autoscaler."
  value       = helm_release.this.name
}
