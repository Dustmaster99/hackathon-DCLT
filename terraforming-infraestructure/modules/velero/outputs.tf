output "bucket_name" {
  description = "Nome do bucket S3 usado pelo Velero."
  value       = aws_s3_bucket.backups.id
}

output "bucket_arn" {
  description = "ARN do bucket S3 usado pelo Velero."
  value       = aws_s3_bucket.backups.arn
}

output "namespace" {
  description = "Namespace no qual o Velero foi instalado."
  value       = kubernetes_namespace_v1.velero.metadata[0].name
}

output "release_name" {
  description = "Nome do Helm release do Velero."
  value       = helm_release.velero.name
}
