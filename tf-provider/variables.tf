variable "rg_location" {
  default     = "eastus"
  description = "Location of the resource group."
}

variable "rg_name_prefix" {
  default     = "nginx_module_rg"
  description = "Prefix of the resource group name"
}

variable "nginx-ziti-module" {
  default = "nginx-ziti-module"
}

variable "include_aks" {
  default = false
}

variable "include_aks_mm" {
  default = false
}

variable "include_aks_nginx" {
  default = false
}
