resource "helm_release" "mattermost" {
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
