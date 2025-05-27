variable "tfstate_bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
}

variable "tfstate_key" {
  description = "Key for Terraform state file"
  type        = string
}

variable "tfstate_region" {
  description = "Region for Terraform state bucket"
  type        = string
}

variable "tfstate_lock_table" {
  description = "DynamoDB table for Terraform state locking"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "eks_cluster_version" {
  description = "EKS cluster version"
  type        = string
}

variable "cicd_nodes_min_size" {
  description = "Minimum size of CICD node group"
  type        = number
}

variable "cicd_nodes_max_size" {
  description = "Maximum size of CICD node group"
  type        = number
}

variable "cicd_nodes_desired_size" {
  description = "Desired size of CICD node group"
  type        = number
}

variable "cicd_nodes_instance_types" {
  description = "Instance types for CICD node group"
  type        = list(string)
}

variable "cicd_nodes_capacity_type" {
  description = "Capacity type for CICD node group"
  type        = string
}

variable "cicd_nodes_disk_size" {
  description = "Disk size for CICD node group"
  type        = number
}

variable "cluster_endpoint_public_access" {
  description = "Enable public access to cluster endpoint"
  type        = bool
}

variable "cluster_endpoint_private_access" {
  description = "Enable private access to cluster endpoint"
  type        = bool
}

variable "keycloak_url" {
  description = "URL for Keycloak server"
  type        = string
}

variable "keycloak_hostname" {
  description = "Hostname for Keycloak ingress"
  type        = string
}

variable "keycloak_frontend_url" {
  description = "Frontend URL for Keycloak"
  type        = string
}

variable "keycloak_certificate_arn" {
  description = "Certificate ARN for Keycloak ingress"
  type        = string
}

variable "project" {
  description = "Project identifier"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
}