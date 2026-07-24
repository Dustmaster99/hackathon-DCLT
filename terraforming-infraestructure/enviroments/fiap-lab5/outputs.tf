output "argocd_external_hostname" {
  description = "Hostname publico do Network Load Balancer exclusivo do Argo CD."
  value       = module.argocd.server_external_hostname
}

output "argocd_external_url" {
  description = "URL HTTPS publica do Argo CD."
  value       = module.argocd.server_external_url
}

output "argocd_application_names" {
  description = "Applications gerenciadas pelo Argo CD."
  value       = module.argocd_applications.application_names
}

output "grafana_external_hostname" {
  description = "Hostname publico do NLB exclusivo do Grafana."
  value       = module.observability.grafana_external_hostname
}

output "grafana_external_url" {
  description = "URL publica do Grafana."
  value       = module.observability.grafana_external_url
}

output "otel_collector_otlp_http_endpoint" {
  description = "Endpoint interno OTLP HTTP usado pelos microservicos."
  value       = module.observability.otel_collector_otlp_http_endpoint
}

output "prometheus_internal_url" {
  description = "URL interna do Prometheus usada pelo Grafana."
  value       = module.observability.prometheus_internal_url
}

output "observability_storage_class" {
  description = "StorageClass gp3 dos volumes persistentes de observabilidade."
  value       = module.observability.storage_class_name
}
