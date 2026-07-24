variable "project_name" {
  description = "Nome do projeto usado como prefixo dos recursos."
  type        = string
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC."
  type        = string
}

variable "availability_zones" {
  description = "Zonas de disponibilidade usadas pelas subnets."
  type        = list(string)
}

variable "public_subnets" {
  description = "Blocos CIDR das subnets públicas."
  type        = list(string)
}

variable "private_subnets" {
  description = "Blocos CIDR das subnets privadas usadas pelos workloads."
  type        = list(string)
}

variable "database_subnets" {
  description = "Blocos CIDR das subnets isoladas para bancos de dados."
  type        = list(string)
}

variable "tags" {
  description = "Tags adicionais aplicadas aos recursos."
  type        = map(string)
  default     = {}
}

