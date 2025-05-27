tfstate_bucket_name       = "ardent-aigs-dev-tfstate-bucket"
tfstate_key               = "aws/dev/shared/terraform.tfstate"
tfstate_region            = "us-east-1"
tfstate_lock_table        = "ardent-aigs-dev-tfstate-locks"

eks_cluster_name          = "aigs-dev-apps-eks"
eks_cluster_version       = "1.31"

cicd_nodes_min_size       = 2
cicd_nodes_max_size       = 4
cicd_nodes_desired_size   = 2
cicd_nodes_instance_types = ["t3.large"]
cicd_nodes_capacity_type  = "ON_DEMAND"
cicd_nodes_disk_size      = 20

cluster_endpoint_public_access  = true
cluster_endpoint_private_access = true

keycloak_url              = "https://dev-keycloak.aivalidator.ardentcloud.com"
keycloak_hostname         = "dev-keycloak.aivalidator.ardentcloud.com"
keycloak_frontend_url     = "https://dev-keycloak.aivalidator.ardentcloud.com/auth"
keycloak_certificate_arn  = "arn:aws:acm:us-east-1:123456789012:certificate/abcd1234-5678-90ab-cdef-EXAMPLE11111"

project          = "aigs"
environment      = "uds-dev"
region           = "us-east-1"
vpc_cidr         = "10.4.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]