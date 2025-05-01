data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket         = "ardent-aigs-dev-tfstate-bucket"
    key            = "aws/dev/shared/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ardent-aigs-dev-tfstate-locks"
    encrypt        = true
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "aigs-dev-apps-eks"
  cluster_version = "1.31"

  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnets

  # Managed Node Group Configuration
  eks_managed_node_groups = {
    cicd_nodes = {
      min_size     = 2
      max_size     = 4
      desired_size = 2

      instance_types = ["t3.large"] # Default instance type
      capacity_type  = "ON_DEMAND"  # Can switch to SPOT for cost savings
      disk_size      = 20           # GiB for each node
    }
  }
  tags = {
    "k8s.io/cluster-autoscaler/enabled"           = "true"
    "k8s.io/cluster-autoscaler/aigs-dev-apps-eks" = "owned"
  }

  # Allow cluster access from Terraform
  enable_cluster_creator_admin_permissions = true

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true # Optional, for internal access too
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.20.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

  enable_aws_load_balancer_controller = true
  enable_cluster_autoscaler           = true

  # Cluster Autoscaler configuration
  cluster_autoscaler = {
    set = [
      {
        name  = "extraArgs.skip-nodes-with-system-pods"
        value = "false"
      },
      {
        name  = "extraArgs.balance-similar-node-groups"
        value = "true"
      },
      {
        name  = "extraArgs.expander"
        value = "least-waste"
      }
    ]
  }
}

# EBS CSI Driver Addon (ensures gp3 support)
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"
  depends_on   = [module.eks]
}

# Attach EBS CSI Policy to Node Role
resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = module.eks.eks_managed_node_groups["cicd_nodes"].iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Kubernetes Provider (to manage StorageClass)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# gp3 StorageClass
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "Immediate" // Change from WaitForFirstConsumer to Immediate
  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }
  depends_on = [aws_eks_addon.ebs_csi]
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

resource "random_password" "apps_postgres_password" {
  length           = 16
  special          = false
}

resource "kubernetes_namespace" "postgres" {
  metadata {
    name = "postgres"
  }
}

resource "kubernetes_secret" "apps_postgres_credentials" {
  metadata {
    name      = "postgres-credentials"
    namespace = "postgres"
  }

  data = {
    password = random_password.apps_postgres_password.result
  }

  type = "Opaque"
  depends_on = [kubernetes_namespace.postgres]
}

resource "helm_release" "postgresql" {
  name       = "postgres"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "15.4.0"

  namespace        = "postgres"
  create_namespace = false
  values = [
    <<-EOT
    fullnameOverride: "postgres"
    global:
      postgresql:
        auth:
          username: "postgresadmin"
          existingSecret: "postgres-credentials"
          secretKeys:
            adminPasswordKey: "password"
          database: "postgresdb"
    persistence:
      enabled: true
      storageClass: "gp3"
      size: 10Gi
    EOT
  ]

  depends_on = [kubernetes_secret.apps_postgres_credentials]
}
resource "kubernetes_namespace" "aidetector" {
  metadata {
    name = "aidetector"
  }
}

resource "kubernetes_secret" "apps_postgres_credentials_aidetector" {
  metadata {
    name      = "postgres-credentials"
    namespace = "aidetector"
  }

  data = {
    password = random_password.apps_postgres_password.result
  }

  type = "Opaque"
  depends_on = [kubernetes_namespace.aidetector]
}

module "minio" {
  source = "./minio"

  namespace             = kubernetes_namespace.aidetector.metadata[0].name
  namespace_dependency  = kubernetes_namespace.aidetector
  storage_size          = "50Gi"
  storage_class_name    = "gp3"
  password_length       = 16
  password_special_chars = false
  root_user             = "minio-admin"
  replicas              = 1
  image                 = "quay.io/minio/minio:latest"
  resource_requests     = {
    memory = "2Gi"
    cpu    = "500m"
  }
  resource_limits       = {
    memory = "4Gi"
    cpu    = "2"
  }
  node_instance_types   = ["t3.xlarge", "t3.2xlarge"]
  ingress_host          = "dev-minio.aivalidator.ardentcloud.com"
  ingress_annotations   = {
    "kubernetes.io/ingress.class"          = "alb"
    "alb.ingress.kubernetes.io/scheme"    = "internet-facing"
    "alb.ingress.kubernetes.io/target-type" = "ip"
    "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTPS\":443}]"
    "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:us-east-1:905418165254:certificate/27e9877d-8ab1-4398-9a31-a859ccf31fe4"
    "alb.ingress.kubernetes.io/ssl-redirect" = "443"
  }

  bucket_name   = "ardent-aidetector"
  bucket_acl    = "public"
  object_uploads = {
    env = {
      object_name  = "configs/.env"
      source       = "./minio/initial-file-uploads/.env"
      content_type = "text/plain"
    }
    ai_sites_supp = {
      object_name  = "data/ai_sites_supp.csv"
      source       = "./minio/initial-file-uploads/ai_sites_supp.csv"
      content_type = "text/csv"
    }
    ai_sites = {
      object_name  = "data/ai_sites.csv"
      source       = "./minio/initial-file-uploads/ai_sites.csv"
      content_type = "text/csv"
    }
    huggingface_models = {
      object_name  = "data/huggingface-models.csv"
      source       = "./minio/initial-file-uploads/huggingface-models.csv"
      content_type = "text/csv"
    }
    kaggle_models = {
      object_name  = "data/kaggle-models.csv"
      source       = "./minio/initial-file-uploads/kaggle-models.csv"
      content_type = "text/csv"
    }
    paperswithcode_models = {
      object_name  = "data/paperswithcode-models.csv"
      source       = "./minio/initial-file-uploads/paperswithcode-models.csv"
      content_type = "text/csv"
    }
    sample_report = {
      object_name  = "reports/report_1FLH8D_2024-07-01_041441.html"
      source       = "./minio/initial-file-uploads/report_1FLH8D_2024-07-01_041441.html"
      content_type = "text/html"
    }
  }

  minio_server = "dev-minio.aivalidator.ardentcloud.com"
  minio_ssl    = true
}

resource "helm_release" "aidetector" {
  name       = "aidetector"
  repository = "oci://905418165254.dkr.ecr.us-east-1.amazonaws.com"
  chart      = "aidetector-helm"
  version    = "0.1.24"

  namespace        = "aidetector"
  create_namespace = false
  recreate_pods    = true

  values = [
    <<-EOT
      fullnameOverride: "aidetector"

      env:
        - name: "NODE_ENV"
          value: "dev"
        - name: "REACT_APP_AWS_BUCKET_ID"
          value: "ardent-aidetector"
        - name: "REACT_APP_API_URL"
          value: "/api"
        - name: "DB_USER"
          value: "postgresadmin"
        - name: "DB_HOST"
          value: "postgres.postgres.svc.cluster.local"
        - name: "DB_DATABASE"
          value: "postgresdb"
        - name: "DB_PASSWORD"
          valueFrom:
            secretKeyRef:
              name: "postgres-credentials"
              key: "password"
        - name: "DB_PORT"
          value: "5432"
        - name: "REACT_APP_MINIO_ENDPOINT"
          value: "https://dev-minio.aivalidator.ardentcloud.com"
        - name: "REACT_APP_MINIO_PORT"
          value: "9000"
        - name: "REACT_APP_MINIO_ACCESS_KEY"
          valueFrom:
            secretKeyRef:
              name: "minio-creds"
              key: "root-user"
        - name: "REACT_APP_MINIO_SECRET_KEY"
          valueFrom:
            secretKeyRef:
              name: "minio-creds"
              key: "root-password"
    EOT
  ]

  depends_on = [module.minio, kubernetes_secret.aidetector_client_secret]
}

output "postgres_password" {
  value     = random_password.apps_postgres_password.result
  sensitive = true
  description = "PostgreSQL admin password"
}

output "minio_root_user" {
  value       = module.minio.minio_root_user
  description = "The MinIO root user"
}

output "minio_root_password" {
  value       = module.minio.minio_root_password
  description = "The MinIO root password"
  sensitive   = true
}

variable "namespace" {
  default = "keycloak"
}

variable "admin_user" {
  default = "admin"
}

resource "random_password" "keycloak_admin_password" {
  length           = 16
  special          = false
}

resource "random_password" "keycloak_db_password" {
  length           = 16
  special          = false
}

resource "kubernetes_namespace" "keycloak" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "keycloak_credentials" {
  metadata {
    name      = "keycloak-credentials"
    namespace = var.namespace
  }

  data = {
    keycloak_admin_password = random_password.keycloak_admin_password.result
    keycloak_db_password    = random_password.keycloak_db_password.result
  }

  type = "Opaque"
  depends_on = [kubernetes_namespace.keycloak]
}

resource "helm_release" "keycloak" {
  name       = "keycloak"
  chart      = "keycloak"
  repository = "https://charts.bitnami.com/bitnami"
  version    = "24.2.0"
  namespace  = var.namespace

  values = [
    <<-EOT
    fullnameOverride: "keycloak"

    auth:
      adminUser: ${var.admin_user}
      adminPassword: ${random_password.keycloak_admin_password.result}

    # Add proxy configuration
    proxy: edge

    # Database configuration
    postgresql:
      enabled: true
      auth:
        username: keycloak
        password: ${random_password.keycloak_db_password.result}
        database: keycloak
      persistence:
        enabled: true
        storageClass: "gp3"
        size: 8Gi

    # Resource settings
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1"

    # Startup probes
    startupProbe:
      enabled: true
      initialDelaySeconds: 60

    # Service configuration
    service:
      type: ClusterIP

    # Ingress configuration
    ingress:
      enabled: true
      ingressClassName: alb
      annotations:
        kubernetes.io/ingress.class: alb
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
        alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:905418165254:certificate/27e9877d-8ab1-4398-9a31-a859ccf31fe4"
        alb.ingress.kubernetes.io/ssl-redirect: '443'
        alb.ingress.kubernetes.io/healthcheck-path: /auth/realms/master
      hostname: dev-keycloak.aivalidator.ardentcloud.com
      path: /
      pathType: Prefix
      tls: true

    # Persistence for Keycloak
    persistence:
      enabled: true
      storageClass: "gp3"

    # Keycloak configuration with proper import setup
    keycloak:
      env:
        KEYCLOAK_FRONTEND_URL: "https://dev-keycloak.aivalidator.ardentcloud.com/auth"
        PROXY_ADDRESS_FORWARDING: "true"
    EOT
  ]

  depends_on = [kubernetes_namespace.keycloak, kubernetes_secret.keycloak_credentials]
}

output "keycloak_admin_password" {
  value     = random_password.keycloak_admin_password.result
  sensitive = true
}

output "keycloak_db_password" {
  value     = random_password.keycloak_db_password.result
  sensitive = true
}

provider "keycloak" {
  client_id     = "admin-cli"
  username      = "admin"
  password      = random_password.keycloak_admin_password.result
  url           = "https://dev-keycloak.aivalidator.ardentcloud.com"
  initial_login = true
}

data "keycloak_openid_client" "aidetector" {
  realm_id  = "ai-guardian-suite"
  client_id = "aidetector"
}

resource "kubernetes_secret" "aidetector_client_secret" {
  metadata {
    name      = "aidetector-client-secret"
    namespace = "aidetector"
  }
  data = {
    "clientId"     = "aidetector"
    "clientSecret" = "${data.keycloak_openid_client.aidetector.client_secret}"
  }

  type = "Opaque"
}

resource "kubernetes_ingress_v1" "aidetector_ingress" {
  metadata {
    name      = "aidetector-ingress"
    namespace = "aidetector"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:us-east-1:905418165254:certificate/27e9877d-8ab1-4398-9a31-a859ccf31fe4"
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "alb.ingress.kubernetes.io/auth-type"       = "oidc"
      "alb.ingress.kubernetes.io/auth-idp-oidc" = jsonencode({
        "Issuer"                = "https://dev-keycloak.aivalidator.ardentcloud.com/realms/ai-guardian-suite"
        "AuthorizationEndpoint" = "https://dev-keycloak.aivalidator.ardentcloud.com/realms/ai-guardian-suite/protocol/openid-connect/auth"
        "TokenEndpoint"         = "https://dev-keycloak.aivalidator.ardentcloud.com/realms/ai-guardian-suite/protocol/openid-connect/token"
        "UserInfoEndpoint"      = "https://dev-keycloak.aivalidator.ardentcloud.com/realms/ai-guardian-suite/protocol/openid-connect/userinfo"
        "SecretName"            = "aidetector-client-secret"
      })
      "alb.ingress.kubernetes.io/auth-on-unauthenticated-request" = "authenticate"
      "alb.ingress.kubernetes.io/auth-session-cookie"             = "AWSELBAuthSessionCookie"
      "alb.ingress.kubernetes.io/auth-session-timeout"            = "300"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = "dev-aidetector.aivalidator.ardentcloud.com"
      http {
        path {
          path      = "/api"
          path_type = "Prefix"
          backend {
            service {
              name = "aidetector-api"
              port {
                number = 3001
              }
            }
          }
        }
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "aidetector-ui"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
  depends_on = [helm_release.aidetector, kubernetes_secret.aidetector_client_secret]
}

resource "kubernetes_role" "alb_controller_secrets_reader" {
  metadata {
    name      = "alb-controller-secrets-reader"
    namespace = "aidetector"
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "alb_controller_secrets_reader" {
  metadata {
    name      = "alb-controller-secrets-reader"
    namespace = "aidetector"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.alb_controller_secrets_reader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "aws-load-balancer-controller-sa"
    namespace = "kube-system"
  }
}

resource "helm_release" "airegistrar" {
  name       = "airegistrar"
  repository = "oci://905418165254.dkr.ecr.us-east-1.amazonaws.com"
  chart      = "airegistrar-helm"
  version    = "0.1.3"

  namespace        = "airegistrar"
  create_namespace = true
  recreate_pods    = true

  values = [
    <<-EOT
      fullnameOverride: "airegistrar"

      env:
        - name: "DATABASE_URL"
          value: "postgresql://postgresadmin:${random_password.apps_postgres_password.result}@postgres.postgres.svc.cluster.local:5432/postgresdb"
        - name: "REACT_APP_API_URL"
          value: "/api"
    EOT
  ]
}

data "keycloak_openid_client" "airegistrar" {
  realm_id  = "ai-guardian-suite"
  client_id = "airegistrar"
}

resource "kubernetes_secret" "airegistrar_client_secret" {
  metadata {
    name      = "airegistrar-client-secret"
    namespace = "airegistrar"
  }
  data = {
    "clientId"     = "airegistrar"
    "clientSecret" = "${data.keycloak_openid_client.airegistrar.client_secret}"
  }

  type = "Opaque"
}

resource "kubernetes_ingress_v1" "airegistrar_ingress" {
  metadata {
    name      = "airegistrar-ingress"
    namespace = "airegistrar"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:us-east-1:905418165254:certificate/27e9877d-8ab1-4398-9a31-a859ccf31fe4"
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "alb.ingress.kubernetes.io/auth-type"       = "oidc"
      "alb.ingress.kubernetes.io/auth-idp-oidc" = jsonencode({
        "Issuer"                = "https://dev-keycloak.aivalidator.ardentcloud.com/realms/ai-guardian-suite"
        "AuthorizationEndpoint" = "https://dev-keycloak.aivalidator.ardentcloud.com/realms/ai-guardian-suite/protocol/openid-connect/auth"
        "TokenEndpoint"         = "https://dev-keycloak.aivalidator.ardentcloud.com/realms/ai-guardian-suite/protocol/openid-connect/token"
        "UserInfoEndpoint"      = "https://dev-keycloak.aivalidator.ardentcloud.com/realms/ai-guardian-suite/protocol/openid-connect/userinfo"
        "SecretName"            = "airegistrar-client-secret"
      })
      "alb.ingress.kubernetes.io/auth-on-unauthenticated-request" = "authenticate"
      "alb.ingress.kubernetes.io/auth-session-cookie"             = "AWSELBAuthSessionCookie"
      "alb.ingress.kubernetes.io/auth-session-timeout"            = "300"
    }
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = "dev-airegistrar.aivalidator.ardentcloud.com"
      http {
        path {
          path      = "/api"
          path_type = "Prefix"
          backend {
            service {
              name = "airegistrar-api"
              port {
                number = 8000
              }
            }
          }
        }
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "airegistrar-ui"
              port {
                number = 3002
              }
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_secret.airegistrar_client_secret]
}

resource "kubernetes_role" "alb_controller_airegistrar_secrets_reader" {
  metadata {
    name      = "alb-controller-secrets-reader"
    namespace = "airegistrar"
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "alb_controller_airegistrar_secrets_reader" {
  metadata {
    name      = "alb-controller-secrets-reader"
    namespace = "airegistrar"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.alb_controller_secrets_reader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "aws-load-balancer-controller-sa"
    namespace = "kube-system"
  }
}