variable "table_name" {
  description = "Nome da tabela DynamoDB."
  type        = string
  default     = "SolidaryTechVolunteers"
}

variable "billing_mode" {
  description = "Modo de cobrança da tabela: PAY_PER_REQUEST ou PROVISIONED."
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode deve ser PAY_PER_REQUEST ou PROVISIONED."
  }
}

variable "hash_key" {
  description = "Nome da chave de partição da tabela."
  type        = string
  default     = "volunteer_id"
}

variable "hash_key_type" {
  description = "Tipo da chave de partição: S, N ou B."
  type        = string
  default     = "S"

  validation {
    condition     = contains(["S", "N", "B"], var.hash_key_type)
    error_message = "hash_key_type deve ser S, N ou B."
  }
}

variable "range_key" {
  description = "Nome da chave de ordenação opcional."
  type        = string
  default     = null
  nullable    = true
}

variable "range_key_type" {
  description = "Tipo da chave de ordenação: S, N ou B."
  type        = string
  default     = "S"

  validation {
    condition     = contains(["S", "N", "B"], var.range_key_type)
    error_message = "range_key_type deve ser S, N ou B."
  }
}

variable "read_capacity" {
  description = "Unidades de leitura quando billing_mode for PROVISIONED."
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Unidades de escrita quando billing_mode for PROVISIONED."
  type        = number
  default     = 5
}

variable "point_in_time_recovery_enabled" {
  description = "Habilita recuperação point-in-time da tabela."
  type        = bool
  default     = true
}

variable "deletion_protection_enabled" {
  description = "Protege a tabela contra exclusão acidental."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags adicionais aplicadas à tabela."
  type        = map(string)
  default     = {}
}

