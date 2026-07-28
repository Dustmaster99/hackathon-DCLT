terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias      = "dr"
  region     = var.velero_backup_region
  profile    = var.aws_profile
  access_key = var.aws_profile == null ? var.aws_access_key_id_secret : null
  secret_key = var.aws_profile == null ? var.aws_secret_access_key_secret : null
  token      = var.aws_profile == null ? var.aws_session_token_secret : null

  default_tags {
    tags = local.common_tags
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  # Isola o Terraform de configuracoes/cache globais do Helm no Windows.
  # Isso evita repositorios obsoletos ou arquivos sem permissao em AppData.
  repository_config_path = "${path.root}/.terraform/helm/repositories.yaml"
  repository_cache       = "${path.root}/.terraform/helm/repository"

  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
