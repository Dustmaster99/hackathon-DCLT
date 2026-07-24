output "application_names" {
  description = "Lista das Applications criadas no Argo CD."
  value       = keys(kubernetes_manifest.argocd_applications)
}

output "applications" {
  description = "Mapa resumido das Applications gerenciadas."
  value = {
    for name, application in var.argocd_applications : name => {
      repository = application.repo_url
      revision   = application.target_revision
      path       = application.path
      namespace  = application.destination_namespace
    }
  }
}
