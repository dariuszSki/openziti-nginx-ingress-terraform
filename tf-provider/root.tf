
resource "azurerm_resource_group" "rg1" {
  location = var.rg_location
  name     = "${var.rg_name_prefix}_${var.rg_location}"
}

module "vnet1" {
  source = "../modules/m-azure-vnet"
  location  =  azurerm_resource_group.rg1.location
  rg_name   = azurerm_resource_group.rg1.name
}

module "aks1" {
  source                    = "../modules/m-azure-aks"
  location                  = azurerm_resource_group.rg1.location
  rg_name                   = azurerm_resource_group.rg1.name
  service_subnet_id         = module.vnet1.service_subnet_id
  node_count                = 2
  private                   = false
  authorized_source_ip_list = var.authorized_source_ip_list
}

output "cluster_name" {
  depends_on = [
    module.aks1
  ]
  value = module.aks1.cluster_name
}

output "cluster_private_fqdn" {
  depends_on = [
    module.aks1
  ]
  value = module.aks1.private_fqdn
}

output "cluster_public_fqdn" {
  depends_on = [
    module.aks1
  ]
  value = module.aks1.public_fqdn
}

module "mattermost" {
  depends_on = [
    module.aks1
  ]
  count        = var.include_aks_mm ? 1 : 0
  source       = "../modules/m-mattermost"
}

module "nginx1" {
  depends_on = [
    module.aks1
  ]
  count               = var.include_aks_nginx ? 1 : 0
  source              = "../modules/m-nginx-ingress"
  nginx_ziti_identity = "${file("./server-nginx.json")}"
}
