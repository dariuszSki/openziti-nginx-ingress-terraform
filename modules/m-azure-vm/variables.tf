variable "location" {}
variable "rg_name" {}
variable "service_subnet_id" {}
variable "vm_prefix" {
  default = "aks-edge-router"
}
variable "admin_user" {
  default = "ziggy"
}
variable "ssh_public_key" {
  default = "~/.ssh/id_rsa.pub"
}
variable "reg_key" {}

