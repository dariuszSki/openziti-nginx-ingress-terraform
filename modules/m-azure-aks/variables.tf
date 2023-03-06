variable "node_count" {
  default = 1
}

variable "node_size" {
  default = "Standard_F2s_v2"
}

variable "cluster_name" {
  default = "akssand"
}

variable "dns_prefix" {
  default = "akssand"
}

variable "tags" {
  default = "AKS Demo"
}

variable "location" {}
variable "rg_name" {}
variable "service_subnet_id" {}

variable "private" {
  default = false
}

variable "ssh_public_key" {
  default = "~/.ssh/id_rsa.pub"
}

