output "minio_service_name" {
  description = "The name of the MinIO service."
  value       = kubernetes_service.minio.metadata[0].name
}

output "minio_ingress_host" {
  description = "The host of the MinIO ingress."
  value       = var.ingress_host
}

output "bucket_id" {
  description = "The ID of the MinIO bucket."
  value       = minio_s3_bucket.bucket.id
}

output "bucket_domain_name" {
  description = "The domain name of the MinIO bucket."
  value       = minio_s3_bucket.bucket.bucket_domain_name
}

output "minio_root_user" {
  value       = var.root_user
  description = "The MinIO root user"
  sensitive   = true
}

output "minio_root_password" {
  value       = random_password.minio_root_password.result
  description = "The MinIO root password"
  sensitive   = true
}