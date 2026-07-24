resource "kubernetes_manifest" "ingress_nginx_service_account" {
  manifest = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "ingress-nginx"
      namespace = var.ingress_nginx_namespace
    }
  }

  depends_on = [kubernetes_namespace_v1.ingress_nginx]
}

resource "kubernetes_manifest" "ingress_nginx_cluster_role" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"
    metadata = {
      name = "solidarytech-ingress-nginx"
    }
    rules = [
      {
        apiGroups = [""]
        resources = ["configmaps", "endpoints", "nodes", "pods", "secrets", "services", "namespaces"]
        verbs     = ["get", "list", "watch"]
      },
      {
        apiGroups = [""]
        resources = ["events"]
        verbs     = ["create", "patch"]
      },
      {
        apiGroups = ["networking.k8s.io"]
        resources = ["ingresses", "ingressclasses"]
        verbs     = ["get", "list", "watch"]
      },
      {
        apiGroups = ["networking.k8s.io"]
        resources = ["ingresses/status"]
        verbs     = ["update"]
      },
      {
        apiGroups = ["discovery.k8s.io"]
        resources = ["endpointslices"]
        verbs     = ["get", "list", "watch"]
      }
    ]
  }
}

resource "kubernetes_manifest" "ingress_nginx_cluster_role_binding" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "solidarytech-ingress-nginx"
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "solidarytech-ingress-nginx"
    }
    subjects = [
      {
        kind      = "ServiceAccount"
        name      = "ingress-nginx"
        namespace = var.ingress_nginx_namespace
      }
    ]
  }

  depends_on = [
    kubernetes_manifest.ingress_nginx_service_account,
    kubernetes_manifest.ingress_nginx_cluster_role
  ]
}

resource "kubernetes_manifest" "ingress_nginx_role" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "Role"
    metadata = {
      name      = "ingress-nginx"
      namespace = var.ingress_nginx_namespace
    }
    rules = [
      {
        apiGroups = [""]
        resources = ["configmaps", "pods", "secrets", "endpoints"]
        verbs     = ["get"]
      },
      {
        apiGroups = [""]
        resources = ["configmaps"]
        verbs     = ["get", "create", "update"]
      },
      {
        apiGroups = [""]
        resources = ["events"]
        verbs     = ["create", "patch"]
      },
      {
        apiGroups = ["coordination.k8s.io"]
        resources = ["leases"]
        verbs     = ["get", "create", "update"]
      }
    ]
  }

  depends_on = [kubernetes_namespace_v1.ingress_nginx]
}

resource "kubernetes_manifest" "ingress_nginx_role_binding" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "RoleBinding"
    metadata = {
      name      = "ingress-nginx"
      namespace = var.ingress_nginx_namespace
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "Role"
      name     = "ingress-nginx"
    }
    subjects = [
      {
        kind      = "ServiceAccount"
        name      = "ingress-nginx"
        namespace = var.ingress_nginx_namespace
      }
    ]
  }

  depends_on = [
    kubernetes_manifest.ingress_nginx_service_account,
    kubernetes_manifest.ingress_nginx_role
  ]
}

resource "kubernetes_manifest" "ingress_nginx_service" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "ingress-nginx-controller"
      namespace = var.ingress_nginx_namespace
      annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-scheme"  = "internet-facing"
        "service.beta.kubernetes.io/aws-load-balancer-type"    = "nlb"
        "service.beta.kubernetes.io/aws-load-balancer-subnets" = join(",", var.public_subnet_ids)
      }
    }
    spec = {
      type = "LoadBalancer"
      selector = {
        "app.kubernetes.io/name" = "ingress-nginx"
      }
      ports = [
        {
          name       = "http"
          port       = 80
          targetPort = 80
          protocol   = "TCP"
        },
        {
          name       = "https"
          port       = 443
          targetPort = 443
          protocol   = "TCP"
        }
      ]
    }
  }

  depends_on = [kubernetes_namespace_v1.ingress_nginx]
}

resource "kubernetes_manifest" "ingress_nginx_controller" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "ingress-nginx-controller"
      namespace = var.ingress_nginx_namespace
      labels = {
        "app.kubernetes.io/name" = "ingress-nginx"
      }
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "ingress-nginx"
        }
      }
      template = {
        metadata = {
          labels = {
            "app.kubernetes.io/name" = "ingress-nginx"
          }
        }
        spec = {
          serviceAccountName = "ingress-nginx"
          containers = [
            {
              name  = "controller"
              image = var.ingress_controller_image
              args = [
                "/nginx-ingress-controller",
                "--publish-service=$(POD_NAMESPACE)/ingress-nginx-controller",
                "--controller-class=k8s.io/ingress-nginx",
                "--ingress-class=nginx",
                "--configmap=$(POD_NAMESPACE)/ingress-nginx-controller"
              ]
              env = [
                {
                  name = "POD_NAME"
                  valueFrom = {
                    fieldRef = {
                      fieldPath = "metadata.name"
                    }
                  }
                },
                {
                  name = "POD_NAMESPACE"
                  valueFrom = {
                    fieldRef = {
                      fieldPath = "metadata.namespace"
                    }
                  }
                }
              ]
              ports = [
                {
                  name          = "http"
                  containerPort = 80
                },
                {
                  name          = "https"
                  containerPort = 443
                }
              ]
            }
          ]
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.ingress_nginx_cluster_role_binding,
    kubernetes_manifest.ingress_nginx_role_binding,
    kubernetes_manifest.ingress_nginx_service
  ]
}

resource "kubernetes_manifest" "ingress_nginx_class" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "IngressClass"
    metadata = {
      name = "nginx"
    }
    spec = {
      controller = "k8s.io/ingress-nginx"
    }
  }

  depends_on = [kubernetes_manifest.ingress_nginx_controller]
}

resource "kubernetes_manifest" "solidarytech_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "solidarytech-ingress"
      namespace = var.fiap_microservices_namespace
    }
    spec = {
      ingressClassName = "nginx"
      rules = [
        {
          http = {
            paths = [
              {
                path     = "/ngos"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "ngo-service"
                    port = {
                      number = 8081
                    }
                  }
                }
              },
              {
                path     = "/donations"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "donation-service"
                    port = {
                      number = 8082
                    }
                  }
                }
              },
              {
                path     = "/volunteers"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "volunteer-service"
                    port = {
                      number = 8083
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.ingress_nginx_class,
    module.microservice_secrets
  ]
}
