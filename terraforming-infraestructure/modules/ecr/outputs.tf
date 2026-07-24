output "repository_names" {
  description = "Nomes dos repositórios ECR criados"
  value       = { for k, v in aws_ecr_repository.repositories : k => v.name }
}

output "repository_urls" {
  description = "URLs dos repositórios ECR criados"
  value       = { for k, v in aws_ecr_repository.repositories : k => v.repository_url }
}

output "repository_arns" {
  description = "ARNs dos repositórios ECR criados"
  value       = { for k, v in aws_ecr_repository.repositories : k => v.arn }
}

output "repository_prefix" {
  description = "Prefixo base dos repositórios ECR do projeto"
  value       = join("/", slice(split("/", values(aws_ecr_repository.repositories)[0].repository_url), 0, 2))
}

