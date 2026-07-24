output "microservices_namespace" {
  description = "Nome do namespace dos componentes SolidaryTech."
  value       = kubernetes_namespace_v1.microservices.metadata[0].name
}

output "ingress_nginx_namespace" {
  description = "Nome do namespace do ingress-nginx."
  value       = kubernetes_namespace_v1.ingress_nginx.metadata[0].name
}

output "argocd_namespace" {
  description = "Nome do namespace reservado para o Argo CD."
  value       = kubernetes_namespace_v1.argocd.metadata[0].name
}

output "secret_names" {
  description = "Nomes dos Secrets criados para os microservicos."
  value       = module.microservice_secrets.secret_names
}
