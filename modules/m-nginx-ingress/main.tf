
resource "kubernetes_secret" "ziti-identity" {
  metadata {
    name = "nginx-ziti-identity"
  }
  data = {
    "nginx-ziti-identity" = var.nginx_ziti_identity
  }
  type = "Opaque"
}

resource "helm_release" "nginx-ingress" {
  name             = "nginx-ingress"
  repository       = "https://helm.nginx.com/stable"
  chart            = "nginx-ingress"
  namespace        = "default"
  create_namespace = false
  version          = "0.16.1" 

  set {
    name = "controller.image.repository"
    value = "docker.io/elblag91/ziti-nginx-ingress"
  }

  set {
    name = "controller.image.tag"
    value = "3.0.2"
  }


  set {
    name = "controller.logLevel"
    value = 1
  }

  values =  [  <<EOF
controller:
  service:
    create: false
  config:
    entries:
      main-snippets: |
        error_log  stderr debug;

        load_module modules/ngx_ziti_module.so;
       
        thread_pool ngx_ziti_tp threads=32 max_queue=65536;

        #ziti identity1 {
        #  identity_file /var/run/secrets/openziti.io/${kubernetes_secret.ziti-identity.metadata[0].name};

        #  bind k8s-api {
        #    upstream kubernetes.default:443;
        #  }
        #}
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
  resources:
    requests:
      cpu: 1
      memory: 1Gi
 EOF
  ]
}
