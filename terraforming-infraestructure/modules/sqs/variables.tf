variable "queue_name" {
  description = "Nome da fila SQS utilizada para eventos de doação."
  type        = string
  default     = "solidary-donations"
}

variable "delay_seconds" {
  description = "Atraso, em segundos, aplicado às novas mensagens."
  type        = number
  default     = 0
}

variable "max_message_size" {
  description = "Tamanho máximo das mensagens, em bytes."
  type        = number
  default     = 262144
}

variable "message_retention_seconds" {
  description = "Tempo de retenção das mensagens na fila principal."
  type        = number
  default     = 345600
}

variable "receive_wait_time_seconds" {
  description = "Tempo de long polling para recebimento de mensagens."
  type        = number
  default     = 20
}

variable "visibility_timeout_seconds" {
  description = "Tempo em que uma mensagem recebida permanece invisível."
  type        = number
  default     = 30
}

variable "create_dead_letter_queue" {
  description = "Cria uma dead-letter queue para mensagens não processadas."
  type        = bool
  default     = true
}

variable "max_receive_count" {
  description = "Quantidade de recebimentos antes do envio da mensagem para a DLQ."
  type        = number
  default     = 5
}

variable "dead_letter_message_retention_seconds" {
  description = "Tempo de retenção das mensagens na dead-letter queue."
  type        = number
  default     = 1209600
}

variable "tags" {
  description = "Tags adicionais aplicadas às filas."
  type        = map(string)
  default     = {}
}

