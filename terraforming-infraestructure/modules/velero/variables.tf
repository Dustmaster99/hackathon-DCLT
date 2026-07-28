variable "project_name" {
  description = "Nome do projeto usado para compor o bucket de backup."
  type        = string
}

variable "backup_region" {
  description = "Regiao AWS do bucket de DR."
  type        = string
}

variable "bucket_name" {
  description = "Nome opcional do bucket. Quando nulo, o modulo gera um nome globalmente unico."
  type        = string
  default     = null
  nullable    = true
}

variable "bucket_prefix" {
  description = "Prefixo usado pelo Velero dentro do bucket."
  type        = string
  default     = "cluster"
}

variable "namespace" {
  description = "Namespace Kubernetes do Velero."
  type        = string
  default     = "velero"
}

variable "release_name" {
  description = "Nome do Helm release."
  type        = string
  default     = "velero"
}

variable "chart_version" {
  description = "Versao do Helm chart oficial do Velero."
  type        = string
  default     = "12.1.0"
}

variable "aws_plugin_version" {
  description = "Versao do plugin AWS compativel com o Velero."
  type        = string
  default     = "v1.13.1"
}

variable "aws_access_key_id" {
  description = "Access key temporaria do AWS Academy."
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "Secret access key temporaria do AWS Academy."
  type        = string
  sensitive   = true
}

variable "aws_session_token" {
  description = "Session token temporario do AWS Academy."
  type        = string
  sensitive   = true
}

variable "backup_schedule" {
  description = "Agenda Cron UTC dos backups."
  type        = string
  default     = "*/15 * * * *"
}

variable "backup_ttl_hours" {
  description = "Retencao dos objetos logicos do Velero em horas."
  type        = number
  default     = 48
}

variable "backup_retention_days" {
  description = "Retencao dos objetos S3 em dias."
  type        = number
  default     = 30
}

variable "noncurrent_version_retention_days" {
  description = "Retencao das versoes nao correntes do bucket."
  type        = number
  default     = 7
}

variable "included_namespaces" {
  description = "Namespaces incluidos no backup agendado."
  type        = list(string)
  default = [
    "fiap-microservices",
    "argocd",
    "ingress-nginx",
    "monitoring"
  ]
}

variable "tags" {
  description = "Tags aplicadas ao bucket."
  type        = map(string)
  default     = {}
}
