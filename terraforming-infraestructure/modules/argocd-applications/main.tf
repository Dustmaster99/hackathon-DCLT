resource "kubernetes_manifest" "argocd_applications" {
  for_each = var.argocd_applications

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"

    metadata = {
      name      = each.key
      namespace = var.argocd_namespace
      labels = {
        "app.kubernetes.io/part-of"    = "solidarytech"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }

    spec = {
      project = "default"

      source = {
        repoURL        = each.value.repo_url
        targetRevision = each.value.target_revision
        path           = each.value.path
      }

      destination = {
        server    = each.value.destination_server
        namespace = each.value.destination_namespace
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }

        retry = {
          limit = 5
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m"
          }
        }

        syncOptions = [
          "CreateNamespace=true",
          "PruneLast=true",
          "PrunePropagationPolicy=foreground"
        ]
      }
    }
  }
}
