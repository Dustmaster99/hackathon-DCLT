resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_storage_class_v1" "gp3" {
  count = var.persistence_enabled ? 1 : 0

  metadata {
    name = var.storage_class_name
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
}

resource "kubernetes_persistent_volume_claim_v1" "otel_collector" {
  count = var.persistence_enabled ? 1 : 0

  metadata {
    name      = "${var.otel_collector_release_name}-data"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class_v1.gp3[0].metadata[0].name

    resources {
      requests = {
        storage = var.otel_collector_persistence_size
      }
    }
  }

  wait_until_bound = false
}

resource "helm_release" "loki" {
  name       = var.loki_release_name
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://grafana-community.github.io/helm-charts"
  chart      = "loki"
  version    = var.loki_chart_version

  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  wait             = true
  timeout          = var.timeout

  values = [
    yamlencode({
      deploymentMode = "SingleBinary"

      loki = {
        auth_enabled = false
        commonConfig = {
          replication_factor = 1
        }
        storage = {
          type = "filesystem"
        }
        schemaConfig = {
          configs = [
            {
              from         = "2024-01-01"
              store        = "tsdb"
              object_store = "filesystem"
              schema       = "v13"
              index = {
                prefix = "index_"
                period = "24h"
              }
            }
          ]
        }
      }

      singleBinary = {
        replicas = 1
        persistence = {
          enabled      = var.persistence_enabled
          storageClass = var.persistence_enabled ? kubernetes_storage_class_v1.gp3[0].metadata[0].name : null
          size         = var.loki_persistence_size
          accessModes  = ["ReadWriteOnce"]
          whenDeleted  = "Retain"
          whenScaled   = "Retain"
        }
      }

      read = {
        replicas = 0
      }
      write = {
        replicas = 0
      }
      backend = {
        replicas = 0
      }

      gateway = {
        enabled = true
      }

      chunksCache = {
        enabled = false
      }
      resultsCache = {
        enabled = false
      }
      minio = {
        enabled = false
      }
    })
  ]
}

resource "helm_release" "prometheus" {
  name       = var.prometheus_release_name
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_chart_version

  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  wait             = true
  timeout          = var.timeout

  values = [
    yamlencode({
      grafana = {
        enabled = false
      }

      prometheus = {
        prometheusSpec = {
          retention = var.prometheus_retention

          additionalScrapeConfigs = [
            {
              job_name        = "otel-collector"
              scrape_interval = "15s"
              static_configs = [
                {
                  targets = [
                    "${var.otel_collector_release_name}.${var.namespace}.svc.cluster.local:8889"
                  ]
                }
              ]
            }
          ]

          resources = {
            requests = {
              cpu    = "100m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }

          storageSpec = var.persistence_enabled ? {
            volumeClaimTemplate = {
              spec = {
                storageClassName = kubernetes_storage_class_v1.gp3[0].metadata[0].name
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_persistence_size
                  }
                }
              }
            }
          } : null
        }
      }

      alertmanager = {
        enabled = true
      }
    })
  ]
}

resource "helm_release" "grafana" {
  name       = var.grafana_release_name
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://grafana-community.github.io/helm-charts"
  chart      = "grafana"
  version    = var.grafana_chart_version

  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  wait             = true
  timeout          = var.timeout

  values = [
    yamlencode({
      adminUser     = var.grafana_admin_user
      adminPassword = var.grafana_admin_password

      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-scheme"  = var.load_balancer_scheme
          "service.beta.kubernetes.io/aws-load-balancer-type"    = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-subnets" = join(",", var.public_subnet_ids)
        }
      }

      persistence = {
        enabled          = var.persistence_enabled && var.grafana_persistence_enabled
        type             = "pvc"
        size             = var.grafana_persistence_size
        storageClassName = var.persistence_enabled ? kubernetes_storage_class_v1.gp3[0].metadata[0].name : null
        accessModes      = ["ReadWriteOnce"]
      }

      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              access    = "proxy"
              url       = "http://${var.prometheus_release_name}-kube-prometheus-prometheus.${var.namespace}.svc.cluster.local:9090"
              isDefault = true
              editable  = false
            },
            {
              name      = "Loki"
              type      = "loki"
              access    = "proxy"
              url       = "http://${var.loki_release_name}-gateway.${var.namespace}.svc.cluster.local"
              isDefault = false
              editable  = false
            }
          ]
        }
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
    })
  ]

  depends_on = [
    helm_release.loki,
    helm_release.prometheus
  ]
}

resource "helm_release" "otel_collector" {
  name       = var.otel_collector_release_name
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = var.otel_collector_chart_version

  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true
  wait             = true
  timeout          = var.timeout

  values = [
    yamlencode({
      fullnameOverride = var.otel_collector_release_name
      mode             = "deployment"

      image = {
        repository = "otel/opentelemetry-collector-contrib"
      }

      command = {
        name = "otelcol-contrib"
      }

      service = {
        enabled = true
        type    = "ClusterIP"
      }

      ports = {
        otlp = {
          enabled       = true
          containerPort = 4317
          servicePort   = 4317
          protocol      = "TCP"
        }
        "otlp-http" = {
          enabled       = true
          containerPort = 4318
          servicePort   = 4318
          protocol      = "TCP"
        }
        prometheus = {
          enabled       = true
          containerPort = 8889
          servicePort   = 8889
          protocol      = "TCP"
        }
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

      extraVolumes = var.persistence_enabled ? [
        {
          name = "otel-storage"
          persistentVolumeClaim = {
            claimName = kubernetes_persistent_volume_claim_v1.otel_collector[0].metadata[0].name
          }
        }
      ] : []

      extraVolumeMounts = var.persistence_enabled ? [
        {
          name      = "otel-storage"
          mountPath = "/var/lib/otelcol"
        }
      ] : []

      config = {
        extensions = merge({
          health_check = {
            endpoint = "0.0.0.0:13133"
          }
          }, var.persistence_enabled ? {
          file_storage = {
            directory = "/var/lib/otelcol"
          }
        } : {})

        receivers = {
          otlp = {
            protocols = {
              grpc = {
                endpoint = "0.0.0.0:4317"
              }
              http = {
                endpoint = "0.0.0.0:4318"
              }
            }
          }
        }

        processors = {
          memory_limiter = {
            check_interval         = "5s"
            limit_percentage       = 80
            spike_limit_percentage = 25
          }
          batch = {}
        }

        exporters = {
          "otlphttp/loki" = {
            endpoint = "http://${var.loki_release_name}-gateway.${var.namespace}.svc.cluster.local/otlp"
            sending_queue = merge({
              enabled    = true
              queue_size = 5000
              }, var.persistence_enabled ? {
              storage = "file_storage"
            } : {})
          }
          prometheus = {
            endpoint = "0.0.0.0:8889"
          }
          debug = {
            verbosity = "basic"
          }
        }

        service = {
          extensions = var.persistence_enabled ? ["health_check", "file_storage"] : ["health_check"]

          pipelines = {
            logs = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"]
              exporters  = ["otlphttp/loki", "debug"]
            }
            metrics = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"]
              exporters  = ["prometheus", "debug"]
            }
            traces = {
              receivers  = ["otlp"]
              processors = ["memory_limiter", "batch"]
              exporters  = ["debug"]
            }
          }
        }
      }
    })
  ]

  depends_on = [helm_release.loki]
}

data "kubernetes_service_v1" "grafana" {
  metadata {
    name      = var.grafana_release_name
    namespace = var.namespace
  }

  depends_on = [helm_release.grafana]
}
