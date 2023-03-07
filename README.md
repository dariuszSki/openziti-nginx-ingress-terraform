
# Secure AKS API with NGINX Ziti Module

## Prerequisites

  - Azure Subscription, Resource Group and [Azure Cli](https://learn.microsoft.com/en-us/cli/azure/)
  - [OpenZiti Nginx Module Repo](https://github.com/openziti/ngx_ziti_module)
  - [Terraform](https://developer.hashicorp.com/terraform/downloads)
  - Openziti Network
  - [Desktop Tunneler](https://docs.openziti.io/docs/reference/tunnelers/)
---
## Architecture:
- Before
![](files/images/nginx-aks-before.svg)
- After 
![](files/images/nginx-aks-after.svg)

---

## Create OpenZiti Network

A couple of ways to do that:
- Follow the guide @[Host OpenZiti](https://docs.openziti.io/docs/learn/quickstarts/network/hosted)
- Follow the guide @[Terraform LKE Setup with OpenZiti](https://github.com/openziti-test-kitchen/terraform-lke-ziti/blob/main/README.md)

Tested with OpenZiti Network deployed  the LKE Cluster using Terraform.

---

## Create NGNIX Server and ZDE Client Identities

Follow the guide @[Create Identities](https://docs.openziti.io/docs/learn/core-concepts/identities/overview#creating-an-identity)

***Note***
client name = `client-nginx` with `Attribute`: `#clients`,  server module name = `server-nginx` with `Attribute`: `#servers`

Download jwt files and enroll identities. 
- Windows ZDE Identity can be enrolled following this [enrolling process](https://docs.openziti.io/docs/reference/tunnelers/windows#enrolling)
- Nginx Module Identity can be enrolled using ziti binary by following this:

```shell
wget $(curl -s https://api.github.com/repos/openziti/ziti/releases/latest | jq -r .assets[].browser_download_url | grep "linux-amd64")
tar -xf $(curl -s https://api.github.com/repos/openziti/ziti/releases/latest | jq -r .assets[].name | grep "linux-amd64") 'ziti/ziti' --strip-components 1; rm $(curl -s https://api.github.com/repos/openziti/ziti/releases/latest | jq -r .assets[].name | grep "linux-amd64")
./ziti edge enroll -j server-nginx.jwt -o server-nginx.json
```
---

# Build NGX Ziti Module and Ingress Controller Image

Currently, configmaps have a binary file limit of 1MB and the size of the ngx-ziti-module is around 2~3MBs. Therefore, the module can be be uploaded to the existing nginx image. One needs to build a custom image and add the module to it during the build process.

- Follow steps to build @[ngx-ziti-module](https://github.com/openziti/ngx_ziti_module/blob/main/README.md#build-using-cmake)
- Follow Steps to create @[nginx ingress controller image](https://docs.nginx.com/nginx-ingress-controller/installation/building-ingress-controller-image/#building-the-image-and-pushing-it-to-the-private-registry)

***Note***
One way to update the build is to add to thier Dockerfile (`build/Dockerfile`) this snippet of code in the common section, i.e. `FROM ${BUILD_OS} as common`
```shell
# copy ziti module
COPY  ./ngx_ziti_module.so /usr/lib/nginx/modules
```
Also, need to add the following package `libc6` to the debian build in the same Dockerfile, i.e. `FROM nginx:1.23.3 AS debian`. Did not try the alpine build but the assumption is that would be the same.
```shell
&& apt-get install --no-install-recommends --no-install-suggests -y libcap2-bin libc6 \
```
Lastly, if you don't want the image name to have a postfix of`SNAPSHOT...` , comment it out in `Makefile`.
```shell
VERSION = $(GIT_TAG)##-SNAPSHOT-$(GIT_COMMIT_SHORT)
```

Once the image is built, upload it to your container registry. You will need it during customization of the nginx ingress controller deployment to the AKS Cluster.

***Note***
if you dont have time to build your own, can use our test image based on debian 11 and nginx v1.23.3 
```shell
set {
    name = "controller.image.repository"
    value = "docker.io/elblag91/ziti-nginx-ingress"
}
```

## Deploy AKS Cluster

Deploy the AKS Infrustructure in Azure. The following resources will be created, when the plan is applied.

- Virtual Network
- AKS Private Cluster with Kubenet CNI and Nginx Ingress Controller

Set a few environmental variables for Azure Authentication and Authorization.

***export ARM_SUBSCRIPTION_ID*** = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

***export ARM_CLIENT_ID*** = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

***export ARM_CLIENT_SECRET*** = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

***export ARM_TENANT_ID*** = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

Run terraform plan.
```shell
git clone https://github.com/dariuszSki/openziti-nginx-ingress-terraform.git
cd openziti-nginx-ingress-terraform/terraform/tf-provider
terraform init
terraform plan  -var include_aks_nginx=true  -out aks
terraform apply "aks"
```

Once completed, grab  `cluster_public_fqdn` under `outputs` as shown in the example below.

```shell
cluster_name = "akssandeastus"
cluster_private_fqdn = ""
cluster_public_fqdn = "akssand-2ift1yqr.hcp.eastus.azmk8s.io"
```

---

## Configuration Code Snippets

If you are using your own deployment method, here are some configuration details from helm chart that need to be passed to the nginx ingress controller deployment.

- ***Ziti Nginx Module Identity***
```shell
nginx_ziti_identity = "${file("./server-nginx.json")}"
resource "kubernetes_secret" "ziti-identity" {
  metadata {
    name = "nginx-ziti-identity"
  }
  data = {
    "nginx-ziti-identity" = var.nginx_ziti_identity
  }
  type = "Opaque"
}
```

- ***Image Reference***
```shell
set {
    name = "controller.image.repository"
    value = "docker.io/elblag91/ziti-nginx-ingress"
  }

set {
    name = "controller.image.tag"
    value = "3.0.2"
}
```

- ***Configuration File - Main section block***

***Info:***
Services are commented out unitl they are created. Then, terraform plan can be rerun to enable them.

```shell
controller:
  service:
    create: false
  config:
    entries:
      main-snippets: |
        load_module modules/ngx_ziti_module.so;
       
        thread_pool ngx_ziti_tp threads=32 max_queue=65536;

        #ziti identity1 {
        #  identity_file /var/run/secrets/openziti.io/${kubernetes_secret.ziti-identity.metadata[0].name};

        #  bind k8s-api {
        #    upstream kubernetes.default:443;
        #  }
        #}
```

- ***Volume section and path to secrets. Added openziti.io folder.***
```bash
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

```

---

## OpenZiti Service Configurations
- ***Create configs***
```shell
ziti edge create config k8s-api-intercept.v1 intercept.v1 "{\"protocols\": [\"tcp\"], \"addresses\": [\"akssand-2ift1yqr.hcp.eastus.azmk8s.io\"],\"portRanges\": [{\"low\": 443,\"high\": 443}]}"
```

- ***Create Service***

```shell
ziti edge create service k8s-api --configs "k8s-api-intercept.v1" --role-attributes "service-nginx"
```

---

- ***Create Service Bind Policy***

```shell
ziti edge create service-policy k8s-api-bind Bind --semantic "AnyOf" --identity-roles "#servers" --service-roles "#service-nginx"
```

---

- ***Create Service Dial Policy***

```shell
ziti edge create service-policy k8s-api-dial Dial --semantic "AnyOf" --identity-roles "#clients" --service-roles "#service-nginx"
```

---

## Enable Ziti Service in Ingress Controller
Uncomment `ziti identity1` block in `resource.helm_release.nginx-ingress`
```shell
config:
    entries:
      main-snippets: |
        load_module modules/ngx_ziti_module.so;
       
        thread_pool ngx_ziti_tp threads=32 max_queue=65536;

        ziti identity1 {
          identity_file /var/run/secrets/openziti.io/${kubernetes_secret.ziti-identity.metadata[0].name};

          bind k8s-api {
            upstream kubernetes.default:443;
          }
        }
```
***Caution***
Need to disable ZDE for this network before the next step, so the nginx updates will not get intercepted while the service is not ready yet.

- ***Re-run terraform***
```bash
terraform plan  -var include_aks_nginx=true  -out aks
terraform apply "aks"
```

---

## Let's test our service

:::tip
If the terraform was run, the kube-config file was created in the tf root directory. One can also use `az cli` to get the kube config downloaded.
```shell
# Configure your local kube configuration file using azure cli
az login # if not already logged in
# Windows WSL
export RG_NAME = 'resource group name'
export ARM_SUBSCRIPTION_ID =  'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
az aks get-credentials --resource-group $RG_NAME --name {cluster_name} --subscription $ARM_SUBSCRIPTION_ID
```
:::

- ***Check context in the kubectl config file***
```shell
kubectl config  get-contexts
```
`Expected Output`
```shell
CURRENT   NAME            CLUSTER         AUTHINFO                                           NAMESPACE
*         akssandeastus   akssandeastus   clusterUser_nginx_module_rg_eastus_akssandeastus   
```

- ***Let's check the status of nodes in the cluster.***
```shell
kubectl get nodes
```
`Expected Output`
```shell
NAME                                STATUS   ROLES   AGE    VERSION
aks-agentpool-20887740-vmss000000   Ready    agent   151m   v1.24.9
aks-agentpool-20887740-vmss000001   Ready    agent   151m   v1.24.9
```

- ***List cluster info***
```shell
kubectl cluster-info
```
`Expected Output`
```shell
Kubernetes control plane is running at https://akssand-2ift1yqr.hcp.eastus.azmk8s.io:443
CoreDNS is running at https://akssand-2ift1yqr.hcp.eastus.azmk8s.io:443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://akssand-2ift1yqr.hcp.eastus.azmk8s.io:443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

- ***List pods***
```shell
kubectl get pods --all-namespaces
```
`Expected Output`
```shell
NAMESPACE     NAME                                           READY   STATUS    RESTARTS   AGE
default       nginx-ingress-nginx-ingress-7ffd564557-ngt69   1/1     Running   0          134m
kube-system   azure-ip-masq-agent-9scx6                      1/1     Running   0          166m
kube-system   azure-ip-masq-agent-xps5g                      1/1     Running   0          166m
kube-system   cloud-node-manager-8q7fk                       1/1     Running   0          166m
kube-system   cloud-node-manager-czg95                       1/1     Running   0          166m
kube-system   coredns-59b6bf8b4f-8t5kj                       1/1     Running   0          165m
kube-system   coredns-59b6bf8b4f-rc6b8                       1/1     Running   0          167m
kube-system   coredns-autoscaler-5655d66f64-pbjhr            1/1     Running   0          167m
kube-system   csi-azuredisk-node-2mp98                       3/3     Running   0          166m
kube-system   csi-azuredisk-node-tq6x6                       3/3     Running   0          166m
kube-system   csi-azurefile-node-9q4f5                       3/3     Running   0          166m
kube-system   csi-azurefile-node-bzr4z                       3/3     Running   0          166m
kube-system   konnectivity-agent-86cdc66d6b-tlhkw            1/1     Running   0          128m
kube-system   konnectivity-agent-86cdc66d6b-ttmq6            1/1     Running   0          128m
kube-system   kube-proxy-q48qv                               1/1     Running   0          166m
kube-system   kube-proxy-t2dhr                               1/1     Running   0          166m
kube-system   metrics-server-8655f897d8-mr2bq                2/2     Running   0          165m
kube-system   metrics-server-8655f897d8-tnpzt                2/2     Running   0          165m
```

- ***List  services***
```shell
kubectl get services --all-namespaces
```
`Expected Output`
```shell
NAMESPACE     NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)         AGE
default       kubernetes       ClusterIP   10.0.0.1       <none>        443/TCP         169m
kube-system   kube-dns         ClusterIP   10.0.0.10      <none>        53/UDP,53/TCP   169m
kube-system   metrics-server   ClusterIP   10.0.218.224   <none>        443/TCP         169m
```
***Note:***
At this point the public access is still available even though the API Kubectl queries are routed through Ziti Network. You can disable ZDE client and test that.

## Block IPs to API Server
Pass the following variable to only allow 192.168.1.1/32 source IP to essentially disable Public Access. 
```shell
terraform plan  -var include_aks_nginx=true -var authorized_source_ip_list=[\"192.168.1.1/32\"] -out aks
terraform apply "aks"
```
Retest with ZDE enabled and disabled for this network.

## Clean up

***Note***
Run terraform to open up the AKS API to public before deleting AKS resources, so you dont get locked out.

```shell
terraform plan  -var include_aks_nginx=true -var authorized_source_ip_list=[\"0.0.0.0/0\"] -out aks
```
```shell
terraform apply "aks"
```
Delete all resources
```shell
terraform plan  --destroy -var include_aks_nginx=true  -out aks
```