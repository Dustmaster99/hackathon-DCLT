data "aws_caller_identity" "current" {}

locals {
  bucket_name = coalesce(
    var.bucket_name,
    "${lower(var.project_name)}-velero-${data.aws_caller_identity.current.account_id}-${var.backup_region}"
  )

  aws_credentials = <<-EOT
    [default]
    aws_access_key_id=${var.aws_access_key_id}
    aws_secret_access_key=${var.aws_secret_access_key}
    aws_session_token=${var.aws_session_token}
  EOT
}

resource "aws_s3_bucket" "backups" {
  bucket = local.bucket_name

  tags = merge(var.tags, {
    Name    = local.bucket_name
    Purpose = "VeleroDisasterRecovery"
  })
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "expire-old-velero-backups"
    status = "Enabled"

    filter {}

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.backups]
}

resource "kubernetes_namespace_v1" "velero" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "velero"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_secret_v1" "cloud_credentials" {
  metadata {
    name      = "velero-cloud-credentials"
    namespace = kubernetes_namespace_v1.velero.metadata[0].name
  }

  data = {
    cloud = local.aws_credentials
  }

  type = "Opaque"
}

resource "helm_release" "velero" {
  name       = var.release_name
  namespace  = kubernetes_namespace_v1.velero.metadata[0].name
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = var.chart_version

  create_namespace = false
  timeout          = 900
  wait             = true

  values = [
    yamlencode({
      initContainers = [
        {
          name            = "velero-plugin-for-aws"
          image           = "velero/velero-plugin-for-aws:${var.aws_plugin_version}"
          imagePullPolicy = "IfNotPresent"
          volumeMounts = [
            {
              mountPath = "/target"
              name      = "plugins"
            }
          ]
        }
      ]

      configuration = {
        backupStorageLocation = [
          {
            name       = "default"
            provider   = "aws"
            bucket     = aws_s3_bucket.backups.id
            prefix     = var.bucket_prefix
            default    = true
            accessMode = "ReadWrite"
            credential = {
              name = kubernetes_secret_v1.cloud_credentials.metadata[0].name
              key  = "cloud"
            }
            config = {
              region = var.backup_region
            }
          }
        ]
        volumeSnapshotLocation   = []
        defaultVolumesToFsBackup = true
        defaultBackupTTL         = "${var.backup_ttl_hours}h"
      }

      credentials = {
        useSecret      = true
        existingSecret = kubernetes_secret_v1.cloud_credentials.metadata[0].name
      }

      backupsEnabled   = true
      snapshotsEnabled = false
      deployNodeAgent  = true

      schedules = {
        "solidarytech-critical" = {
          disabled                   = false
          schedule                   = var.backup_schedule
          useOwnerReferencesInBackup = false
          template = {
            ttl                      = "${var.backup_ttl_hours}h"
            storageLocation          = "default"
            includedNamespaces       = var.included_namespaces
            snapshotVolumes          = false
            defaultVolumesToFsBackup = true
          }
        }
      }

      metrics = {
        enabled = true
        serviceMonitor = {
          autodetect = true
          enabled    = true
        }
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }

      nodeAgent = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
    })
  ]

  depends_on = [
    aws_s3_bucket_public_access_block.backups,
    aws_s3_bucket_server_side_encryption_configuration.backups,
    aws_s3_bucket_versioning.backups,
    kubernetes_secret_v1.cloud_credentials
  ]
}
