variable "fiap_microservices_namespace" {
  description = "Namespace Kubernetes dos componentes SolidaryTech."
  type        = string
  default     = "fiap-microservices"
}

variable "ingress_nginx_namespace" {
  description = "Namespace Kubernetes do ingress-nginx."
  type        = string
  default     = "ingress-nginx"
}

variable "argocd_namespace" {
  description = "Namespace Kubernetes reservado para o Argo CD."
  type        = string
  default     = "argocd"
}

variable "public_subnet_ids" {
  description = "Subnets publicas usadas pelo Network Load Balancer do ingress."
  type        = list(string)
}

variable "aws_region" {
  description = "Regiao AWS usada pelos microservicos."
  type        = string
}

variable "aws_access_key_id" {
  description = "Access key ID disponibilizada aos microservicos."
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "Secret access key disponibilizada aos microservicos."
  type        = string
  sensitive   = true
}

variable "aws_session_token" {
  description = "Session token disponibilizado aos microservicos."
  type        = string
  sensitive   = true
  default     = ""
}

variable "sqs_url" {
  description = "URL da fila SQS do donation-service."
  type        = string
}

variable "dynamodb_table" {
  description = "Nome da tabela DynamoDB do volunteer-service."
  type        = string
}

variable "postgres_user" {
  description = "Usuario do PostgreSQL."
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "Senha do PostgreSQL."
  type        = string
  sensitive   = true
}

variable "postgres_database" {
  description = "Banco padrao do PostgreSQL."
  type        = string
  default     = "postgres"
}

variable "ngo_database_name" {
  description = "Nome do banco do ngo-service."
  type        = string
  default     = "ngo_db"
}

variable "donation_database_name" {
  description = "Nome do banco do donation-service."
  type        = string
  default     = "donation_db"
}

variable "ingress_controller_image" {
  description = "Imagem do controller ingress-nginx."
  type        = string
  default     = "registry.k8s.io/ingress-nginx/controller:v1.14.1"
}
