variable "namespace" {
  description = "The Kubernetes namespace to deploy resources into."
  type        = string
  default     = "aidetector" // Ensure this matches your namespace
}

variable "namespace_dependency" {
  description = "Dependency on the namespace resource."
  type        = any
  default     = null // Ensure this is set to the namespace resource
}

variable "storage_size" {
  description = "The size of the persistent volume claim."
  type        = string
  default     = "100Gi"
}

variable "storage_class_name" {
  description = "The storage class name for the PVC."
  type        = string
  default     = "gp3"
}

variable "password_length" {
  description = "Length of the generated password."
  type        = number
  default     = 16
}

variable "password_special_chars" {
  description = "Whether the generated password should include special characters."
  type        = bool
  default     = false
}

variable "root_user" {
  description = "The root user for MinIO."
  type        = string
  default     = "minio-admin"
}

variable "replicas" {
  description = "Number of replicas for the MinIO deployment."
  type        = number
  default     = 1
}

variable "image" {
  description = "The container image for MinIO."
  type        = string
  default     = "quay.io/minio/minio:latest"
}

variable "resource_requests" {
  description = "Resource requests for the MinIO container."
  type        = map(string)
  default     = {
    memory = "2Gi"
    cpu    = "500m"
  }
}

variable "resource_limits" {
  description = "Resource limits for the MinIO container."
  type        = map(string)
  default     = {
    memory = "4Gi"
    cpu    = "2"
  }
}

variable "node_instance_types" {
  description = "Preferred node instance types for scheduling."
  type        = list(string)
  default     = ["t3.large", "t3.xlarge", "t3.2xlarge"] // Ensure this matches your cluster nodes
}

variable "ingress_annotations" {
  description = "Annotations for the ingress resource."
  type        = map(string)
  default     = {
    "kubernetes.io/ingress.class"          = "alb"
    "alb.ingress.kubernetes.io/scheme"    = "internet-facing"
    "alb.ingress.kubernetes.io/target-type" = "ip"
    "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTPS\":443}]"
    "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:us-east-1:905418165254:certificate/27e9877d-8ab1-4398-9a31-a859ccf31fe4"
    "alb.ingress.kubernetes.io/ssl-redirect" = "443"
  }
}

variable "ingress_host" {
  description = "The host for the ingress resource."
  type        = string
  default     = "dev-minio.aivalidator.ardentcloud.com"
}

variable "bucket_name" {
  description = "The name of the MinIO bucket."
  type        = string
}

variable "bucket_acl" {
  description = "The ACL for the MinIO bucket."
  type        = string
  default     = "public"
}

variable "object_uploads" {
  description = "A map of objects to upload to the MinIO bucket."
  type = map(object({
    object_name  = string
    source       = string
    content_type = string
  }))
  default = {}
}

variable "minio_server" {
  description = "The MinIO server endpoint."
  type        = string
}

variable "minio_ssl" {
  description = "Whether to use SSL for the MinIO provider."
  type        = bool
  default     = true
}
