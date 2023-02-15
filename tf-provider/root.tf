variable "SUB_ID" {}
variable "nginx-ziti-module" {
  default = "nginx-ziti-module"
}

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

resource "kubernetes_secret" "ziti-identity" {
  metadata {
    name = "nginx-ziti-identity"
  }
  data = {
    "nginx-ziti-identity" = "${file("~/nginx-aks-01.json")}"
  }
  type = "Opaque"
}
/*
resource "kubernetes_secret" "ziti-module" {
  metadata {
    name = "nginx-ziti-module"
  }
  data = {
    "nginx-ziti-module" = "${file("~/ngx_ziti_module")}"
  }
  type = "Opaque"
}
*/
resource "kubernetes_manifest" "configmap-nginx" {
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ConfigMap"
    "metadata" = {
      "name"       = "nginx-configuration"
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
#load_module /tmp/ngx_ziti_module.so;
#thread_pool ngx_ziti_tp threads=32 max_queue=65536;
#ziti identity1 {
#    identity_file /var/run/secrets/openziti.io/${kubernetes_secret.ziti-identity.metadata[0].name};
#
#    bind mattermost {
#        upstream 10.0.177.157:8065;
#    }
#}
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
    value = true
  }

  set {
    name = "controller.service.create"
    value = true
  }

  values =  [  <<EOF
controller:
  volumes:
      - name: "ziti-nginx-files"
        projected:
          defaultMode: 420
          sources:
          - secret:
              name: ${kubernetes_secret.ziti-identity.metadata[0].name}
              items: 
              - key: ${kubernetes_secret.ziti-identity.metadata[0].name}
                path: ${kubernetes_secret.ziti-identity.metadata[0].name}
  volumeMounts:
    - mountPath: /var/run/secrets/openziti.io
      name: ziti-nginx-files
      readOnly: true
 EOF
  ]
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

  values = [ <<EOF
ingress:
  enabled: true
  hosts:
    - mattermost.demo.io
configJSON:
  ServiceSettings:
    SiteURL: "http://mattermost.demo.io"
  TeamSettings:
    SiteName: "Mattermost East on demo.io"
  EOF
  ]

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

