variable "namespace" {
  description = "Namespace onde a stack de observabilidade sera instalada."
  type        = string
  default     = "monitoring"
}

variable "public_subnet_ids" {
  description = "Subnets publicas usadas pelo Network Load Balancer exclusivo do Grafana."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) > 0
    error_message = "public_subnet_ids deve conter pelo menos uma subnet publica."
  }
}

variable "aws_resource_tags" {
  description = "Tags aplicadas aos recursos AWS criados indiretamente pela stack de observabilidade."
  type        = map(string)
}

variable "storage_class_name" {
  description = "Nome da StorageClass gp3 gerenciada pelo modulo."
  type        = string
  default     = "solidarytech-gp3"
}

variable "persistence_enabled" {
  description = "Habilita StorageClass e volumes persistentes EBS para a stack de observabilidade."
  type        = bool
  default     = true
}

variable "grafana_release_name" {
  description = "Nome da release Helm do Grafana."
  type        = string
  default     = "grafana"
}

variable "grafana_chart_version" {
  description = "Versao do chart Helm do Grafana."
  type        = string
  default     = "12.7.2"
}

variable "grafana_admin_user" {
  description = "Usuario administrador inicial do Grafana."
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Senha inicial do administrador do Grafana."
  type        = string
  sensitive   = true
}

variable "grafana_persistence_enabled" {
  description = "Habilita persistencia dos dados e dashboards do Grafana."
  type        = bool
  default     = true
}

variable "grafana_persistence_size" {
  description = "Tamanho do volume persistente do Grafana."
  type        = string
  default     = "5Gi"
}

variable "load_balancer_scheme" {
  description = "Esquema do Network Load Balancer do Grafana."
  type        = string
  default     = "internet-facing"

  validation {
    condition     = contains(["internet-facing", "internal"], var.load_balancer_scheme)
    error_message = "load_balancer_scheme deve ser internet-facing ou internal."
  }
}

variable "prometheus_release_name" {
  description = "Nome da release Helm do kube-prometheus-stack."
  type        = string
  default     = "prometheus"
}

variable "kube_prometheus_stack_chart_version" {
  description = "Versao do chart Helm kube-prometheus-stack."
  type        = string
  default     = "87.18.1"
}

variable "prometheus_retention" {
  description = "Periodo de retencao das metricas do Prometheus."
  type        = string
  default     = "7d"
}

variable "prometheus_persistence_size" {
  description = "Tamanho do volume persistente do Prometheus."
  type        = string
  default     = "20Gi"
}

variable "loki_release_name" {
  description = "Nome da release Helm do Loki."
  type        = string
  default     = "loki"
}

variable "loki_chart_version" {
  description = "Versao do chart Helm do Loki."
  type        = string
  default     = "18.5.0"
}

variable "loki_persistence_size" {
  description = "Tamanho do volume persistente do Loki."
  type        = string
  default     = "10Gi"
}

variable "otel_collector_release_name" {
  description = "Nome da release e do Service do OpenTelemetry Collector."
  type        = string
  default     = "otel-collector"
}

variable "otel_collector_chart_version" {
  description = "Versao do chart Helm do OpenTelemetry Collector."
  type        = string
  default     = "0.158.2"
}

variable "otel_collector_persistence_size" {
  description = "Tamanho do volume persistente usado pela fila do OpenTelemetry Collector."
  type        = string
  default     = "5Gi"
}

variable "timeout" {
  description = "Timeout das instalacoes Helm em segundos."
  type        = number
  default     = 900
}
