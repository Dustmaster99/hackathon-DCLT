locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  count = var.enable_ebs_persistence ? 1 : 0

  name               = "${var.project_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = var.enable_ebs_persistence ? 1 : 0

  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "vpc" {
  source = "../../modules/vpc"

  project_name = "solidarytech"
  vpc_cidr     = var.vpc_cidr

  availability_zones = [
    "us-east-1a",
    "us-east-1b"
  ]

  public_subnets = [
    "10.0.2.0/24",
    "10.0.4.0/24"
  ]

  private_subnets = [
    "10.0.1.0/24",
    "10.0.3.0/24"
  ]

  database_subnets = []

  tags = {
    Project     = "SolidaryTech"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = "microservices-eks-cluster"
  cluster_version = var.eks_cluster_version

  cluster_role_arn = var.eks_cluster_role_arn
  node_role_arn    = var.eks_node_role_arn

  node_group_name    = "microservices-eks-nodes"
  private_subnet_ids = module.vpc.private_subnet_ids

  instance_types = ["t3.large"]
  capacity_type  = "SPOT"
  disk_size      = 20

  desired_size = 1
  min_size     = 0
  max_size     = 2

  max_unavailable = 1

  cluster_addons = merge({
    coredns                   = null
    kube-proxy                = null
    metrics-server            = null
    vpc-cni                   = null
    eks-node-monitoring-agent = null
    }, var.enable_ebs_persistence ? {
    eks-pod-identity-agent = null
    aws-ebs-csi-driver     = null
  } : {})

  addon_pod_identity_associations = var.enable_ebs_persistence ? {
    aws-ebs-csi-driver = {
      role_arn        = aws_iam_role.ebs_csi[0].arn
      service_account = "ebs-csi-controller-sa"
    }
  } : {}

  tags = {
    Project     = "SolidaryTech"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }

  depends_on = [aws_iam_role_policy_attachment.ebs_csi]
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = "solidarytech"

  repositories = [
    "ngo-service",
    "donation-service",
    "volunteer-service",
    "postgres"
  ]

  image_tag_mutability = "MUTABLE"
  scan_on_push         = true

  tags = {
    Project     = "SolidaryTech"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}

module "volunteers_dynamodb" {
  source = "../../modules/dynamodb"

  table_name    = "SolidaryTechVolunteers"
  billing_mode  = "PAY_PER_REQUEST"
  hash_key      = "volunteer_id"
  hash_key_type = "S"

  tags = {
    Project     = "SolidaryTech"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}

module "donation_events_sqs" {
  source = "../../modules/sqs"

  queue_name = "solidary-donations"

  tags = {
    Project     = "SolidaryTech"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}

module "cluster_manifests" {
  source = "../../modules/cluster-manifests"

  fiap_microservices_namespace = "fiap-microservices"
  ingress_nginx_namespace      = "ingress-nginx"
  argocd_namespace             = "argocd"
  public_subnet_ids            = module.vpc.public_subnet_ids

  aws_region = var.aws_region

  aws_access_key_id     = var.aws_access_key_id_secret
  aws_secret_access_key = var.aws_secret_access_key_secret
  aws_session_token     = var.aws_session_token_secret

  sqs_url        = module.donation_events_sqs.queue_url
  dynamodb_table = module.volunteers_dynamodb.table_name

  postgres_user          = var.postgres_user_secret
  postgres_password      = var.postgres_password_secret
  postgres_database      = "postgres"
  ngo_database_name      = "ngo_db"
  donation_database_name = "donation_db"
}

module "argocd" {
  source = "../../modules/argocd"

  namespace            = module.cluster_manifests.argocd_namespace
  release_name         = "argocd"
  chart_version        = "10.1.3"
  server_service_type  = "LoadBalancer"
  public_subnet_ids    = module.vpc.public_subnet_ids
  load_balancer_scheme = "internet-facing"

  controller_replicas  = 1
  server_replicas      = 1
  repo_server_replicas = 1
  timeout              = 900

  depends_on = [module.cluster_manifests]
}

module "argocd_applications" {
  source = "../../modules/argocd-applications"

  argocd_namespace    = module.argocd.namespace
  argocd_applications = var.argocd_applications

  depends_on = [module.argocd]
}

module "observability" {
  source = "../../modules/observability"

  namespace           = "monitoring"
  public_subnet_ids   = module.vpc.public_subnet_ids
  storage_class_name  = "solidarytech-gp3"
  persistence_enabled = var.enable_ebs_persistence

  grafana_release_name        = "grafana"
  grafana_chart_version       = "12.7.2"
  grafana_admin_user          = var.grafana_admin_user
  grafana_admin_password      = var.grafana_admin_password
  grafana_persistence_enabled = true
  grafana_persistence_size    = "5Gi"
  load_balancer_scheme        = "internet-facing"

  prometheus_release_name             = "prometheus"
  kube_prometheus_stack_chart_version = "87.18.1"
  prometheus_retention                = "7d"
  prometheus_persistence_size         = "20Gi"

  loki_release_name     = "loki"
  loki_chart_version    = "18.5.0"
  loki_persistence_size = "10Gi"

  otel_collector_release_name     = "otel-collector"
  otel_collector_chart_version    = "0.158.2"
  otel_collector_persistence_size = "5Gi"

  depends_on = [module.cluster_manifests]
}
