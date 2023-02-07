resource "azurerm_resource_group" "rg1" {
  location = var.resource_group_location
  name     = var.resource_group_name_prefix
}

module "vnet1" {
  source = "../modules/m-azure-vnet"
  resource_group_location =  azurerm_resource_group.rg1.location
  resource_group_name_prefix = azurerm_resource_group.rg1.name
}

module "aks1" {
  source            = "../modules/m-azure-aks"
  location          = azurerm_resource_group.rg1.location
  rg_name           = azurerm_resource_group.rg1.name
  service_subnet_id = module.vnet1.service_subnet_id
}

module "vm1" {
  source            = "../modules/m-azure-vm"
  location          = azurerm_resource_group.rg1.location
  rg_name           = azurerm_resource_group.rg1.name
  service_subnet_id = module.vnet1.service_subnet_id 
  reg_key           = ""
}