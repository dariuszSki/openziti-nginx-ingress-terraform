resource "azurerm_kubernetes_cluster" "aks" {
  location                = var.location
  name                    = "${var.cluster_name}${var.location}"
  resource_group_name     = var.rg_name
  dns_prefix              = var.dns_prefix
  private_cluster_enabled = var.private
  
  tags                = {
    Environment = var.tags
  }

  api_server_access_profile {
    authorized_ip_ranges = ["64.86.230.135/32"]
  }

  default_node_pool {
    name            = "agentpool"
    vm_size         = var.node_size
    node_count      = var.node_count
    os_disk_size_gb = 30
    vnet_subnet_id  = var.service_subnet_id
  }

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = file(var.ssh_public_key)
    }
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }

  identity {
    type = "SystemAssigned"
  }

}
