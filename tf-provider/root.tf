variable "SUB_ID" {}

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
  reg_key           = "48ZHV6RPIQ"
}

data "azurerm_kubernetes_cluster" "aks" {
  name                = module.aks1.cluster_name
  resource_group_name = azurerm_resource_group.rg1.name
}

resource "kubernetes_manifest" "configmap-nginx" {
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ConfigMap"
    "metadata" = {
      "name"       = "nginx-configuration5"
      "namespace"  = "default"
      "labels" = {
        "app"                       = "nginx-ingress"
        "app.kubernetes.io/name"    = "nginx-ingress"
        "app.kubernetes.io/part-of" = "nginx-ingress"
      }
    }
    "data" = {
      "main-snippets" = <<EOH
error_log  /var/log/nginx/error.log debug;
load_module /tmp/ngx_ziti_module.so;
thread_pool ngx_ziti_tp threads=32 max_queue=65536;
ziti identity1 {
    identity_file /tmp/nginx-aks-01.json;

    bind mattermost {
        upstream 10.244.0.79:8065;
    }
}
EOH
    }
  }
}

resource "helm_release" "nginx-ingress" {
  depends_on       = [
    data.azurerm_kubernetes_cluster.aks
  ]
  name             = "nginx-ingress"
  repository       = "https://helm.nginx.com/stable"
  chart            = "nginx-ingress"
  namespace        = "default"
  create_namespace = false
  version          = "0.16.1" 

  set {
    name = "controller.customConfigMap"
    value = kubernetes_manifest.configmap-nginx.manifest.metadata.name
  }

  set {
    name  = "controller.nginxplus"
    value = false
  }

  set {
    name = "nginxServiceMesh.enableEgress"
    value = false
  }

  set {
    name = "controller.service.create"
    value = false
  }

}

resource "helm_release" "mattermost" {
  depends_on       = [data.azurerm_kubernetes_cluster.aks]
  name             = "mattermost"
  repository       = "https://helm.mattermost.com/"
  chart            = "mattermost-team-edition"
  namespace        = "mattermost"
  create_namespace = true
  set {
    name  = "mysql.mysqlUser"
    value = "ziggy"
  }
  set {
    name  = "mysql.mysqlPassword"
    value = "ziggy"
  }
}

output "kube_config" {
  value     = data.azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

resource "null_resource" "kubectl" {
    provisioner "local-exec" {
        command = "az aks get-credentials --resource-group ${azurerm_resource_group.rg1.name} --name ${module.aks1.cluster_name} --subscription ${var.SUB_ID}"
    }
}

