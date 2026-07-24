variable "namespace" {
  description = "Namespace Kubernetes onde os Secrets serao criados."
  type        = string
  default     = "fiap-microservices"

  validation {
    condition     = length(trimspace(var.namespace)) > 0
    error_message = "namespace nao pode ser vazio."
  }
}

variable "aws_region" {
  description = "Regiao AWS usada pelos microservicos."
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key_id" {
  description = "Access key ID usada pelos microservicos que acessam recursos AWS."
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "Secret access key usada pelos microservicos que acessam recursos AWS."
  type        = string
  sensitive   = true
}

variable "aws_session_token" {
  description = "Session token das credenciais temporarias AWS. Deixe vazio para credenciais permanentes."
  type        = string
  sensitive   = true
  default     = ""
}

variable "sqs_url" {
  description = "URL da fila SQS utilizada pelo donation-service."
  type        = string
}

variable "dynamodb_table" {
  description = "Nome da tabela DynamoDB utilizada pelo volunteer-service."
  type        = string
}

variable "postgres_user" {
  description = "Usuario administrador do PostgreSQL."
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "Senha do usuario administrador do PostgreSQL."
  type        = string
  sensitive   = true
}

variable "postgres_database" {
  description = "Banco padrao criado pela imagem PostgreSQL."
  type        = string
  default     = "postgres"
}

variable "ngo_database_name" {
  description = "Nome do banco de dados do ngo-service."
  type        = string
  default     = "ngo_db"
}

variable "donation_database_name" {
  description = "Nome do banco de dados do donation-service."
  type        = string
  default     = "donation_db"
}

variable "postgres_service_name" {
  description = "Nome do Service Kubernetes do PostgreSQL."
  type        = string
  default     = "postgres"
}

variable "postgres_service_port" {
  description = "Porta do Service Kubernetes do PostgreSQL."
  type        = number
  default     = 5432
}

variable "ngo_service_port" {
  description = "Porta do ngo-service."
  type        = number
  default     = 8081
}

variable "donation_service_port" {
  description = "Porta do donation-service."
  type        = number
  default     = 8082
}

variable "volunteer_service_port" {
  description = "Porta do volunteer-service."
  type        = number
  default     = 8083
}
