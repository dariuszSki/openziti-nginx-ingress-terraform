
resource "random_string" "resource_code" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_resource_group" "tfstate" {
  name     = var.rg_name
  location = var.location
}

resource "azurerm_storage_account" "tfstate" {
  depends_on = [
    azurerm_resource_group.tfstate
  ]
  name                     = "${var.rg_name}${random_string.resource_code.result}"
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {}
}

resource "azurerm_storage_container" "tfstate" {
  depends_on = [
    azurerm_storage_account.tfstate
  ]
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

resource "null_resource" "storage_account_key" {
  depends_on = [
    azurerm_storage_container.tfstate
  ]
    provisioner "local-exec" {
        command = "export ARM_ACCESS_KEY=${azurerm_storage_account.tfstate.primary_access_key}"
    }
}

output "storage_account_name"{
  value = azurerm_storage_account.tfstate.name
}
