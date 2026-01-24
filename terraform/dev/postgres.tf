resource "azurerm_postgresql_flexible_server" "postgres_01" {
  name                = "pg-jobdirect-dev"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location

  #administrator_login    = "pgadmin"
  #administrator_password = var.postgres_admin_password

  version                = "15"
  administrator_login    = "jobdirectadmin"
  administrator_password = "Proyectos123"

  sku_name = "B_Standard_B1ms"

  storage_mb = 32768


  backup_retention_days = 7
  #ssl_enforcement_enabled = true
  zone = "1"

  tags = {
    Environment = "Development"
    Project     = "JobDirect"
  }
}

resource "azurerm_postgresql_flexible_server_database" "db_jobdirect" {
  name      = "jobdirect"
  server_id = azurerm_postgresql_flexible_server.postgres_01.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.postgres_01.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}


output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.postgres_01.fqdn
}

output "postgres_connection_string" {
  value     = "postgresql://jobdirectadmin:Proyectos123@${azurerm_postgresql_flexible_server.postgres_01.fqdn}:5432/jobdirect?sslmode=require"
  sensitive = true
}

