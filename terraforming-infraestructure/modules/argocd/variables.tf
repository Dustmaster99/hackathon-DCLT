variable "namespace" {
  description = "Namespace existente onde o Argo CD sera instalado."
  type        = string
  default     = "argocd"

  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "namespace nao pode ser vazio."
  }
}

variable "release_name" {
  description = "Nome da release Helm do Argo CD."
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Versao do chart Helm oficial argo-cd."
  type        = string
  default     = "10.1.3"
}

variable "server_service_type" {
  description = "Tipo do Service do Argo CD Server."
  type        = string
  default     = "LoadBalancer"

  validation {
    condition     = contains(["ClusterIP", "LoadBalancer", "NodePort"], var.server_service_type)
    error_message = "server_service_type deve ser ClusterIP, LoadBalancer ou NodePort."
  }
}

variable "public_subnet_ids" {
  description = "Subnets publicas usadas pelo Network Load Balancer exclusivo do Argo CD."
  type        = list(string)
  default     = []

  validation {
    condition     = var.server_service_type != "LoadBalancer" || length(var.public_subnet_ids) > 0
    error_message = "public_subnet_ids deve conter ao menos uma subnet quando server_service_type for LoadBalancer."
  }
}

variable "load_balancer_scheme" {
  description = "Esquema do Load Balancer do Argo CD."
  type        = string
  default     = "internet-facing"

  validation {
    condition     = contains(["internet-facing", "internal"], var.load_balancer_scheme)
    error_message = "load_balancer_scheme deve ser internet-facing ou internal."
  }
}

variable "timeout" {
  description = "Timeout da instalacao Helm em segundos."
  type        = number
  default     = 900

  validation {
    condition     = var.timeout >= 300
    error_message = "timeout deve ser de pelo menos 300 segundos."
  }
}

variable "controller_replicas" {
  description = "Quantidade de replicas do application-controller."
  type        = number
  default     = 1
}

variable "server_replicas" {
  description = "Quantidade de replicas do Argo CD Server."
  type        = number
  default     = 1
}

variable "repo_server_replicas" {
  description = "Quantidade de replicas do repo-server."
  type        = number
  default     = 1
}
