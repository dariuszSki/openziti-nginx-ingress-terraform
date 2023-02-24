
resource "azurerm_resource_group" "rg1" {
  location = var.resource_group_location
  name     = var.resource_group_name_prefix
}

module "vnet1" {
  source = "../modules/m-azure-vnet"
  location  =  azurerm_resource_group.rg1.location
  rg_name   = azurerm_resource_group.rg1.name
}

module "aks1" {
  source            = "../modules/m-azure-aks"
  location          = azurerm_resource_group.rg1.location
  rg_name           = azurerm_resource_group.rg1.name
  service_subnet_id = module.vnet1.service_subnet_id
  node_count        = 1
}

module "vm1" {
  source            = "../modules/m-azure-vm"
  location          = azurerm_resource_group.rg1.location
  rg_name           = azurerm_resource_group.rg1.name
  service_subnet_id = module.vnet1.service_subnet_id
  reg_key           = "LGYB5G34DU"
}

module "mattermost" {
  depends_on = [
    module.aks1,
    data.azurerm_kubernetes_cluster.aks
  ]
  source       = "../modules/m-mattermost"
}

module "nginx1" {
  depends_on = [
    module.aks1,
    data.azurerm_kubernetes_cluster.aks
  ]
  source = "../modules/m-nginx-ingress"
  nginx_ziti_identity = "${file("~/nginx-aks-01.json")}"
}

data "azurerm_kubernetes_cluster" "aks" {
  name                = module.aks1.cluster_name
  resource_group_name = azurerm_resource_group.rg1.name
}
 
output "kube_config" {
  depends_on = [
    module.aks1
  ]
  value     = module.aks1.kube_config
  sensitive = true
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

output "router_public_ip_address" {
  depends_on = [
    module.vm1,
    module.aks1
  ]
  value = module.vm1.public_ip
}