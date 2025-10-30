resource "helm_release" "metrics_server" {
  count            = var.eks_enabled == true ? 1 : 0
  name             = "metrics-server"
  namespace        = "metrics-server"
  create_namespace = true

  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.1"

  cleanup_on_fail = true

  set = [{
    name  = "containerPort"
    value = "4443"
  }]

}

