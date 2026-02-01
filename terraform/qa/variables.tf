variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
  sensitive   = true
}

variable "postgres_admin_password" {
  type        = string
  description = "PostgreSQL administrator password"
  sensitive   = true
}
