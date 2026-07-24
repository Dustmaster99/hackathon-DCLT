variable "cluster_name" {
  description = "Nome do cluster EKS."
  type        = string
}

variable "cluster_version" {
  description = "Versão do Kubernetes usada pelo EKS."
  type        = string
}

variable "cluster_role_arn" {
  description = "ARN da role IAM utilizada pelo control plane do EKS."
  type        = string
}

variable "node_role_arn" {
  description = "ARN da role IAM utilizada pelos worker nodes."
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas onde o cluster e os nodes serão implantados."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) > 0
    error_message = "Informe ao menos uma subnet privada para o cluster."
  }
}

variable "endpoint_private_access" {
  description = "Habilita acesso privado ao endpoint da API Kubernetes."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Habilita acesso público ao endpoint da API Kubernetes."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs autorizados a acessar publicamente a API Kubernetes."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_group_name" {
  description = "Nome do managed node group."
  type        = string
  default     = "eks-node-group"
}

variable "ami_type" {
  description = "Tipo de AMI utilizado pelos worker nodes."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "instance_types" {
  description = "Tipos de instância permitidos para os worker nodes."
  type        = list(string)
  default     = ["t3.small"]
}

variable "capacity_type" {
  description = "Tipo de capacidade do node group: ON_DEMAND ou SPOT."
  type        = string
  default     = "SPOT"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type deve ser ON_DEMAND ou SPOT."
  }
}

variable "disk_size" {
  description = "Tamanho, em GiB, do disco dos worker nodes."
  type        = number
  default     = 20
}

variable "desired_size" {
  description = "Quantidade desejada inicial de worker nodes."
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Quantidade mínima de worker nodes."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Quantidade máxima de worker nodes."
  type        = number
  default     = 2
}

variable "max_unavailable" {
  description = "Quantidade máxima de nodes indisponíveis durante atualizações."
  type        = number
  default     = 1
}

variable "cluster_addons" {
  description = "Mapa de add-ons do EKS. Use null como versão para selecionar a versão padrão da AWS."
  type        = map(string)
  default = {
    coredns                   = null
    kube-proxy                = null
    vpc-cni                   = null
    eks-pod-identity-agent    = null
    eks-node-monitoring-agent = null
  }
}

variable "addon_pod_identity_associations" {
  description = "Associacoes de EKS Pod Identity por nome de add-on."
  type = map(object({
    role_arn        = string
    service_account = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags adicionais aplicadas aos recursos."
  type        = map(string)
  default     = {}
}
