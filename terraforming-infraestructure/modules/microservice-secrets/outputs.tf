output "aws_credentials_secret_name" {
  description = "Nome do Secret com as credenciais AWS."
  value       = kubernetes_secret_v1.aws_credentials.metadata[0].name
}

output "ngo_secret_name" {
  description = "Nome do Secret do ngo-service."
  value       = kubernetes_secret_v1.ngo_secret.metadata[0].name
}

output "donation_secret_name" {
  description = "Nome do Secret do donation-service."
  value       = kubernetes_secret_v1.donation_secret.metadata[0].name
}

output "volunteer_secret_name" {
  description = "Nome do Secret do volunteer-service."
  value       = kubernetes_secret_v1.volunteer_secret.metadata[0].name
}

output "postgres_secret_name" {
  description = "Nome do Secret do PostgreSQL."
  value       = kubernetes_secret_v1.postgres_secret.metadata[0].name
}

output "secret_names" {
  description = "Mapa com todos os Secrets Kubernetes gerenciados pelo modulo."
  value = {
    aws_credentials = kubernetes_secret_v1.aws_credentials.metadata[0].name
    ngo             = kubernetes_secret_v1.ngo_secret.metadata[0].name
    donation        = kubernetes_secret_v1.donation_secret.metadata[0].name
    volunteer       = kubernetes_secret_v1.volunteer_secret.metadata[0].name
    postgres        = kubernetes_secret_v1.postgres_secret.metadata[0].name
  }
}
