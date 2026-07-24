output "cluster_id" {
  description = "ID do cluster EKS."
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "ARN do cluster EKS."
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint da API Kubernetes."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificado da autoridade certificadora do cluster, codificado em base64."
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_version" {
  description = "Versão Kubernetes do cluster."
  value       = aws_eks_cluster.main.version
}

output "node_group_arn" {
  description = "ARN do managed node group."
  value       = aws_eks_node_group.main.arn
}

output "node_group_status" {
  description = "Status do managed node group."
  value       = aws_eks_node_group.main.status
}

