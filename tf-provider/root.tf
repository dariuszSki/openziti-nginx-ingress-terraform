resource "azurerm_resource_group" "rg1" {
  location = var.resource_group_location
  name     = var.resource_group_name_prefix
}

module "vnet1" {
  source = "../modules/m-azure-vnet"
  resource_group_location =  azurerm_resource_group.rg1.location
  resource_group_name_prefix = azurerm_resource_group.rg1.name
}