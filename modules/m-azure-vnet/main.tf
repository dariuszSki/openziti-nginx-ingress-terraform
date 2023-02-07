resource "azurerm_virtual_network" "vnet1" {
    name                = "nginx-module-net"
    location            = var.resource_group_location
    resource_group_name = var.resource_group_name_prefix
    address_space       = ["10.10.0.0/16"]

    tags = {}
}

resource "azurerm_subnet" "service-subnet" {
    name                 = "nginx-module-srv-snet"
    resource_group_name  = var.resource_group_name_prefix
    virtual_network_name = azurerm_virtual_network.vnet1.name
    address_prefixes     = ["10.10.0.0/24"]
}

resource "azurerm_subnet" "app-subnet" {
    name                 = "nginx-module-app-snet"
    resource_group_name  = var.resource_group_name_prefix
    virtual_network_name = azurerm_virtual_network.vnet1.name
    address_prefixes     = ["10.10.1.0/24"]
}