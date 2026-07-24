locals {
  postgres_connection_prefix = "postgresql://${urlencode(var.postgres_user)}:${urlencode(var.postgres_password)}@${var.postgres_service_name}:${var.postgres_service_port}"
}

resource "kubernetes_secret_v1" "aws_credentials" {
  metadata {
    name      = "aws-credentials"
    namespace = var.namespace
  }

  type = "Opaque"

  data = {
    AWS_ACCESS_KEY_ID     = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
    AWS_SESSION_TOKEN     = var.aws_session_token
  }
}

resource "kubernetes_secret_v1" "ngo_secret" {
  metadata {
    name      = "ngo-secret"
    namespace = var.namespace
  }

  type = "Opaque"

  data = {
    PORT         = tostring(var.ngo_service_port)
    DATABASE_URL = "${local.postgres_connection_prefix}/${var.ngo_database_name}"
  }
}

resource "kubernetes_secret_v1" "donation_secret" {
  metadata {
    name      = "donation-secret"
    namespace = var.namespace
  }

  type = "Opaque"

  data = {
    PORT         = tostring(var.donation_service_port)
    DATABASE_URL = "${local.postgres_connection_prefix}/${var.donation_database_name}"
    AWS_REGION   = var.aws_region
    AWS_SQS_URL  = var.sqs_url
  }
}

resource "kubernetes_secret_v1" "volunteer_secret" {
  metadata {
    name      = "volunteer-secret"
    namespace = var.namespace
  }

  type = "Opaque"

  data = {
    PORT               = tostring(var.volunteer_service_port)
    AWS_REGION         = var.aws_region
    AWS_DYNAMODB_TABLE = var.dynamodb_table
  }
}

resource "kubernetes_secret_v1" "postgres_secret" {
  metadata {
    name      = "postgres-secret"
    namespace = var.namespace
  }

  type = "Opaque"

  data = {
    POSTGRES_USER     = var.postgres_user
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_DB       = var.postgres_database
    NGO_DB_NAME       = var.ngo_database_name
    DONATION_DB_NAME  = var.donation_database_name
  }
}
