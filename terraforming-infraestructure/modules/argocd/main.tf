resource "helm_release" "argocd" {
  name       = var.release_name
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  wait             = true
  timeout          = var.timeout

  values = [
    yamlencode({
      crds = {
        install = true
      }

      controller = {
        replicas = var.controller_replicas
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }

      server = {
        replicas = var.server_replicas
        service = {
          type = var.server_service_type
          annotations = var.server_service_type == "LoadBalancer" ? {
            "service.beta.kubernetes.io/aws-load-balancer-scheme"  = var.load_balancer_scheme
            "service.beta.kubernetes.io/aws-load-balancer-type"    = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-subnets" = join(",", var.public_subnet_ids)
          } : {}
        }
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }
      }

      repoServer = {
        replicas = var.repo_server_replicas
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }
      }

      applicationSet = {
        replicas = 1
      }

      notifications = {
        enabled = true
      }

      dex = {
        enabled = false
      }
    })
  ]
}

data "kubernetes_service_v1" "argocd_server" {
  metadata {
    name      = "${var.release_name}-server"
    namespace = var.namespace
  }

  depends_on = [helm_release.argocd]
}
