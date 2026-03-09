data "archive_file" "prometheus_values" {
  count       = var.eks_enabled == true ? 1 : 0
  type        = "zip"
  source_file = "${var.values_file_path}/values-${var.env}.yaml"
  output_path = "/tmp/prometheus_helm_dir_checksum.zip"
}

resource "helm_release" "prometheus_crds" {
  name       = "prometheus-crds"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "79.5.0"

  namespace  = "monitoring"
  create_namespace = true

  wait = true

  set = [
    {
      name  = "prometheus.enabled"
      value = "false"
    },
    {
      name  = "alertmanager.enabled"
      value = "false"
    },

    {
      name  = "grafana.enabled"
      value = "false"
    }
  ]
}

resource "helm_release" "prometheus" {
  count            = var.eks_enabled == true ? 1 : 0
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "79.5.0"
  namespace        = "monitoring"
  create_namespace = true
  wait    = true
  timeout = 600

  values = [templatefile("${var.values_file_path}/values-${var.env}.yaml", {
    subnets = join(",", var.subnets)
  })]

  depends_on = [
    helm_release.prometheus_crds
  ]

  # lifecycle {
  #   ignore_changes = [
  #     values,
  #     set
  #   ]
  # }
}
