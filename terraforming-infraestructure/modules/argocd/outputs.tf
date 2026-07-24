output "namespace" {
  description = "Namespace onde o Argo CD foi instalado."
  value       = var.namespace
}

output "release_name" {
  description = "Nome da release Helm do Argo CD."
  value       = helm_release.argocd.name
}

output "chart_version" {
  description = "Versao instalada do chart argo-cd."
  value       = helm_release.argocd.version
}

output "status" {
  description = "Status da release Helm do Argo CD."
  value       = helm_release.argocd.status
}

output "server_service_name" {
  description = "Nome esperado do Service do Argo CD Server."
  value       = "${var.release_name}-server"
}

output "server_external_hostname" {
  description = "Hostname externo atribuido pela AWS ao Load Balancer do Argo CD."
  value       = try(data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "server_external_url" {
  description = "URL HTTPS externa do Argo CD."
  value = try(
    "https://${data.kubernetes_service_v1.argocd_server.status[0].load_balancer[0].ingress[0].hostname}",
    null
  )
}
