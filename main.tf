module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = ["10.4.1.0/24", "10.4.2.0/24"]
  public_subnets  = ["10.4.101.0/24", "10.4.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                         = 1
    "kubernetes.io/cluster/${var.project}-${var.environment}-eks" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                = 1
    "kubernetes.io/cluster/${var.project}-${var.environment}-eks" = "shared"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Managed Node Group Configuration
  eks_managed_node_groups = {
    cicd_nodes = {
      min_size     = var.cicd_nodes_min_size
      max_size     = var.cicd_nodes_max_size
      desired_size = var.cicd_nodes_desired_size

      instance_types = var.cicd_nodes_instance_types
      capacity_type  = var.cicd_nodes_capacity_type
      disk_size      = var.cicd_nodes_disk_size
    }
  }
  tags = {
    "k8s.io/cluster-autoscaler/enabled"           = "true"
    "k8s.io/cluster-autoscaler/${var.eks_cluster_name}" = "owned"
  }

  # Allow cluster access from Terraform
  enable_cluster_creator_admin_permissions = true

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access
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

    proxy: edge

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

    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1"

    startupProbe:
      enabled: true
      initialDelaySeconds: 60

    service:
      type: ClusterIP

    ingress:
      enabled: true
      ingressClassName: alb
      annotations:
        kubernetes.io/ingress.class: alb
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
        alb.ingress.kubernetes.io/certificate-arn: ${var.keycloak_certificate_arn}
        alb.ingress.kubernetes.io/ssl-redirect: '443'
        alb.ingress.kubernetes.io/healthcheck-path: /auth/realms/master
      hostname: ${var.keycloak_hostname}
      path: /
      pathType: Prefix
      tls: true

    keycloak:
      env:
        KEYCLOAK_FRONTEND_URL: ${var.keycloak_frontend_url}
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
  url           = var.keycloak_url
  initial_login = true
}