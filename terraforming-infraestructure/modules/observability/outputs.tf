output "namespace" {
  description = "Namespace da stack de observabilidade."
  value       = kubernetes_namespace_v1.monitoring.metadata[0].name
}

output "storage_class_name" {
  description = "StorageClass gp3 usada pelos componentes de observabilidade."
  value       = try(kubernetes_storage_class_v1.gp3[0].metadata[0].name, null)
}

output "otel_collector_pvc_name" {
  description = "PVC usado pela fila persistente do OpenTelemetry Collector."
  value       = try(kubernetes_persistent_volume_claim_v1.otel_collector[0].metadata[0].name, null)
}

output "grafana_service_name" {
  description = "Nome do Service externo do Grafana."
  value       = var.grafana_release_name
}

output "grafana_external_hostname" {
  description = "Hostname publico atribuido pela AWS ao NLB do Grafana."
  value       = try(data.kubernetes_service_v1.grafana.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "grafana_external_url" {
  description = "URL HTTP publica do Grafana."
  value = try(
    "http://${data.kubernetes_service_v1.grafana.status[0].load_balancer[0].ingress[0].hostname}",
    null
  )
}

output "loki_gateway_service_name" {
  description = "Nome do Service gateway do Loki."
  value       = "${var.loki_release_name}-gateway"
}

output "prometheus_service_name" {
  description = "Nome do Service interno do Prometheus."
  value       = "${var.prometheus_release_name}-kube-prometheus-prometheus"
}

output "prometheus_internal_url" {
  description = "URL interna do Prometheus usada pelo Grafana."
  value       = "http://${var.prometheus_release_name}-kube-prometheus-prometheus.${var.namespace}.svc.cluster.local:9090"
}

output "otel_collector_service_name" {
  description = "Nome do Service do OpenTelemetry Collector."
  value       = var.otel_collector_release_name
}

output "otel_collector_otlp_grpc_endpoint" {
  description = "Endpoint interno OTLP gRPC."
  value       = "${var.otel_collector_release_name}.${var.namespace}.svc.cluster.local:4317"
}

output "otel_collector_otlp_http_endpoint" {
  description = "Endpoint interno OTLP HTTP."
  value       = "http://${var.otel_collector_release_name}.${var.namespace}.svc.cluster.local:4318"
}

output "otel_collector_prometheus_endpoint" {
  description = "Endpoint interno coletado pelo Prometheus."
  value       = "${var.otel_collector_release_name}.${var.namespace}.svc.cluster.local:8889"
}
