terraform {
  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = "3.3.0"
    }
  }
}


resource "kubernetes_persistent_volume_claim" "minio_pvc" {
  metadata {
    name      = "minio-pvc"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.storage_size
      }
    }
    storage_class_name = var.storage_class_name
  }
}

resource "random_password" "minio_root_password" {
  length  = var.password_length
  special = var.password_special_chars
}

provider "minio" {
  minio_server   = var.minio_server
  minio_user     = var.root_user
  minio_password = random_password.minio_root_password.result
  minio_ssl      = var.minio_ssl
}

resource "kubernetes_secret" "minio_creds" {
  metadata {
    name      = "minio-creds"
    namespace = var.namespace
  }

  type = "Opaque"

  data = {
    root-user     = var.root_user
    root-password = random_password.minio_root_password.result
  }

  depends_on = [var.namespace_dependency]
}

resource "kubernetes_pod" "minio" {
  metadata {
    name      = "minio"
    namespace = var.namespace
    labels = {
      app = "minio"
    }
  }

  spec {
    container {
      name  = "minio"
      image = var.image
      command = ["/bin/bash", "-c"]
      args    = ["minio server /data --console-address :9090"]

      env {
        name = "MINIO_ROOT_USER"
        value_from {
          secret_key_ref {
            name = kubernetes_secret.minio_creds.metadata[0].name
            key  = "root-user"
          }
        }
      }

      env {
        name = "MINIO_ROOT_PASSWORD"
        value_from {
          secret_key_ref {
            name = kubernetes_secret.minio_creds.metadata[0].name
            key  = "root-password"
          }
        }
      }

      volume_mount {
        name       = "minio-storage"
        mount_path = "/data"
      }

      resources {
        requests = var.resource_requests
        limits   = var.resource_limits
      }
    }

    volume {
      name = "minio-storage"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.minio_pvc.metadata[0].name
      }
    }
  }
}

resource "kubernetes_service" "minio" {
  metadata {
    name      = "minio"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "minio"
    }

    port {
      name       = "api"
      port       = 9000
      target_port = 9000
    }

    port {
      name       = "console"
      port       = 9090
      target_port = 9090
    }
  }
}

resource "kubernetes_ingress_v1" "minio_ingress" {
  metadata {
    name      = "minio-ingress"
    namespace = var.namespace
    annotations = var.ingress_annotations
  }

  spec {
    rule {
      host = var.ingress_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.minio.metadata[0].name
              port {
                number = 9000
              }
            }
          }
        }
      }
    }
  }
}

resource "minio_s3_bucket" "bucket" {
  bucket = var.bucket_name
  acl    = var.bucket_acl
}

resource "minio_s3_object" "uploads" {
  for_each = var.object_uploads

  bucket_name  = minio_s3_bucket.bucket.bucket
  object_name  = each.value.object_name
  source       = each.value.source
  content_type = each.value.content_type

  depends_on = [minio_s3_bucket.bucket]
}
