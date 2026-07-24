variable "argocd_namespace" {
  description = "Namespace onde o Argo CD esta instalado."
  type        = string
  default     = "argocd"

  validation {
    condition     = length(trimspace(var.argocd_namespace)) > 0
    error_message = "argocd_namespace nao pode ser vazio."
  }
}

variable "argocd_applications" {
  description = "Mapa de Applications gerenciadas pelo Argo CD."
  type = map(object({
    repo_url              = string
    target_revision       = string
    path                  = string
    destination_server    = string
    destination_namespace = string
  }))

  validation {
    condition     = length(var.argocd_applications) > 0
    error_message = "argocd_applications deve conter pelo menos uma aplicacao."
  }
}
