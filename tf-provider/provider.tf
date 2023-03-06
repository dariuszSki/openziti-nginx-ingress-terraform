terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.0"
    }	
  }
  backend "local" {}
  #backend "azurerm" {
  #  resource_group_name  = "tfstate"
  #  container_name       = "tfstate"
  #  key                  = "nginx.module.tfstate"
  #}
}

provider "azurerm" {
  features {
    api_management {
      purge_soft_delete_on_destroy = true
    }
  }
}

provider "kubernetes" {
  host                   = module.aks1.host
  client_key             = base64decode(module.aks1.client_key)
  client_certificate     = base64decode(module.aks1.client_certificate)
  cluster_ca_certificate = base64decode(module.aks1.cluster_ca_certificate)
  
}

provider "helm" {
  debug   = true
  kubernetes {
    host                   = module.aks1.host
    client_key             = base64decode(module.aks1.client_key)
    client_certificate     = base64decode(module.aks1.client_certificate)
    cluster_ca_certificate = base64decode(module.aks1.cluster_ca_certificate)
  }
}