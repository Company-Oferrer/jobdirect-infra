resource "azurerm_resource_group" "rg_01" {
  name     = "rg-jobdirect-dev-eastus-01"
  location = "West US 3"
  tags = {
    Project     = "JobDirect"
    Environment = "Development"
  }
}

resource "azurerm_kubernetes_cluster" "aks_01" {
  name                = "aks-jobdirect-dev-eastus-01"
  location            = azurerm_resource_group.rg_01.location
  resource_group_name = azurerm_resource_group.rg_01.name
  dns_prefix          = "aksdns"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "standard_a2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Development"
    Project     = "JobDirect"
  }
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.aks_01.kube_config[0].client_certificate
  sensitive = true
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks_01.kube_config_raw
  sensitive = true
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks_01.name
}

output "resource_group_name" {
  value = azurerm_resource_group.rg_01.name
}
