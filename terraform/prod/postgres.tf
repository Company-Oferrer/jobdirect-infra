resource "azurerm_postgresql_flexible_server" "postgres_01" {
  name                   = "psql-jobdirect-prod-eastus-01"
  resource_group_name    = azurerm_resource_group.rg_01.name
  location               = azurerm_resource_group.rg_01.location
  version                = "15"
  administrator_login    = "jobdirectadmin"
  administrator_password = var.postgres_admin_password

  storage_mb = 131072 # 128 GB
  sku_name   = "GP_Standard_D4s_v3"

  backup_retention_days        = 35
  geo_redundant_backup_enabled = true

  tags = {
    Environment = "Production"
    Project     = "JobDirect"
  }
}

resource "azurerm_postgresql_flexible_server_database" "db_jobdirect" {
  name      = "jobdirect"
  server_id = azurerm_postgresql_flexible_server.postgres_01.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Permitir acceso desde Azure services (incluye AKS)
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.postgres_01.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.postgres_01.fqdn
}

output "postgres_connection_string" {
  value     = "postgresql://jobdirectadmin:${var.postgres_admin_password}@${azurerm_postgresql_flexible_server.postgres_01.fqdn}:5432/jobdirect?sslmode=require"
  sensitive = true
}
