variable "project_name" {
  description = "Nome do projeto usado como prefixo dos repositórios"
  type        = string
}

variable "repositories" {
  description = "Lista de nomes dos repositórios ECR"
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "Mutabilidade das tags"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Habilita scan de imagem no push"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags dos recursos"
  type        = map(string)
  default     = {}
}

