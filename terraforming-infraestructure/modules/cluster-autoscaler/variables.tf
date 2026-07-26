variable "cluster_name" {
  description = "Nome do cluster EKS gerenciado pelo Cluster Autoscaler."
  type        = string
}

variable "aws_region" {
  description = "Regiao AWS do cluster e dos Auto Scaling Groups."
  type        = string
}

variable "chart_version" {
  description = "Versao do chart Helm oficial do Cluster Autoscaler."
  type        = string
}

variable "kubernetes_version" {
  description = "Versao major.minor do Kubernetes, usada para selecionar a imagem compativel."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version deve usar o formato major.minor, por exemplo 1.35."
  }
}

variable "namespace" {
  description = "Namespace onde o Cluster Autoscaler sera instalado."
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "ServiceAccount associado a role IAM por EKS Pod Identity."
  type        = string
  default     = "cluster-autoscaler"
}

variable "tags" {
  description = "Tags aplicadas aos recursos IAM do Cluster Autoscaler."
  type        = map(string)
  default     = {}
}
