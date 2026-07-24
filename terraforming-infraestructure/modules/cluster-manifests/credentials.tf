module "microservice_secrets" {
  source = "../microservice-secrets"

  namespace  = kubernetes_namespace_v1.microservices.metadata[0].name
  aws_region = var.aws_region

  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
  aws_session_token     = var.aws_session_token

  sqs_url        = var.sqs_url
  dynamodb_table = var.dynamodb_table

  postgres_user          = var.postgres_user
  postgres_password      = var.postgres_password
  postgres_database      = var.postgres_database
  ngo_database_name      = var.ngo_database_name
  donation_database_name = var.donation_database_name

  postgres_service_name = "postgres"
  postgres_service_port = 5432

  ngo_service_port       = 8081
  donation_service_port  = 8082
  volunteer_service_port = 8083
}
