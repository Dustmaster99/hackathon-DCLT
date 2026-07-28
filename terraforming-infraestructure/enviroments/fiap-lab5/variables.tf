variable "aws_region" {
  description = "Regiao AWS onde os recursos serao criados."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Perfil local da AWS CLI. Use null para utilizar a cadeia padrao de credenciais."
  type        = string
  default     = null
  nullable    = true
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "eks_cluster_version" {
  description = "Versao do Kubernetes utilizada pelo cluster EKS."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.eks_cluster_version))
    error_message = "eks_cluster_version deve usar o formato major.minor, por exemplo 1.30."
  }
}

variable "eks_cluster_role_arn" {
  description = "ARN da role IAM utilizada pelo control plane do EKS."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-zA-Z-]*:iam::[0-9]{12}:role/.+$", var.eks_cluster_role_arn))
    error_message = "eks_cluster_role_arn deve ser um ARN valido de uma role IAM."
  }
}

variable "eks_node_role_arn" {
  description = "ARN da role IAM utilizada pelos worker nodes do EKS."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-zA-Z-]*:iam::[0-9]{12}:role/.+$", var.eks_node_role_arn))
    error_message = "eks_node_role_arn deve ser um ARN valido de uma role IAM."
  }
}

variable "enable_ebs_persistence" {
  description = "Habilita o EBS CSI, a role IAM associada e os volumes persistentes da observabilidade."
  type        = bool
  default     = false
}

variable "enable_cluster_autoscaler" {
  description = "Habilita o Cluster Autoscaler e os recursos IAM e Pod Identity associados."
  type        = bool
  default     = false
}

variable "project_name" {
  description = "Nome do projeto usado na identificacao e nas tags dos recursos."
  type        = string
  default     = "fiap-lab5"

  validation {
    condition     = length(trimspace(var.project_name)) > 0
    error_message = "project_name nao pode ser vazio."
  }
}

variable "environment" {
  description = "Nome do ambiente da infraestrutura."
  type        = string
  default     = "lab"

  validation {
    condition     = contains(["dev", "test", "staging", "lab", "prod"], var.environment)
    error_message = "environment deve ser dev, test, staging, lab ou prod."
  }
}

variable "additional_tags" {
  description = "Tags adicionais aplicadas aos recursos gerenciados pelo provider AWS."
  type        = map(string)
  default     = {}
}

variable "aws_access_key_id_secret" {
  description = "Access key ID disponibilizada aos microservicos no Secret Kubernetes."
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key_secret" {
  description = "Secret access key disponibilizada aos microservicos no Secret Kubernetes."
  type        = string
  sensitive   = true
}

variable "aws_session_token_secret" {
  description = "Session token disponibilizado aos microservicos no Secret Kubernetes."
  type        = string
  sensitive   = true
  default     = ""
}

variable "postgres_user_secret" {
  description = "Usuario do PostgreSQL disponibilizado aos containers e usado nas URLs de conexao."
  type        = string
  sensitive   = true
}

variable "postgres_password_secret" {
  description = "Senha do PostgreSQL disponibilizada aos containers e usada nas URLs de conexao."
  type        = string
  sensitive   = true
}

variable "argocd_applications" {
  description = "Mapa das Applications que o Argo CD sincroniza a partir do Git."
  type = map(object({
    repo_url              = string
    target_revision       = string
    path                  = string
    destination_server    = string
    destination_namespace = string
  }))
}

variable "grafana_admin_user" {
  description = "Usuario administrador inicial do Grafana."
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Senha inicial do administrador do Grafana."
  type        = string
  sensitive   = true
}

variable "enable_datadog" {
  description = "Habilita a exportacao da telemetria do ambiente para o Datadog."
  type        = bool
  default     = false
}

variable "datadog_site" {
  description = "Site regional da organizacao Datadog."
  type        = string
  default     = "datadoghq.com"
}

variable "datadog_api_key" {
  description = "API key de ingestao do Datadog. Informe por TF_VAR_datadog_api_key."
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_velero" {
  description = "Habilita o bucket S3 cross-region e a instalacao do Velero sem criar IAM Role."
  type        = bool
  default     = false
}

variable "velero_backup_region" {
  description = "Regiao do bucket S3 usado para Disaster Recovery."
  type        = string
  default     = "us-west-2"
}

variable "velero_bucket_name" {
  description = "Nome opcional do bucket Velero. Quando nulo, um nome unico e gerado."
  type        = string
  default     = null
  nullable    = true
}

variable "velero_chart_version" {
  description = "Versao do Helm chart oficial do Velero."
  type        = string
  default     = "12.1.0"
}

variable "velero_aws_plugin_version" {
  description = "Versao do plugin AWS para o Velero."
  type        = string
  default     = "v1.13.1"
}

variable "velero_backup_schedule" {
  description = "Agenda Cron UTC do backup dos namespaces criticos."
  type        = string
  default     = "*/15 * * * *"
}

variable "velero_backup_ttl_hours" {
  description = "Retencao dos backups do Velero em horas."
  type        = number
  default     = 48
}

variable "velero_included_namespaces" {
  description = "Namespaces incluidos no backup agendado do Velero."
  type        = list(string)
  default = [
    "fiap-microservices",
    "argocd",
    "ingress-nginx",
    "monitoring"
  ]
}
