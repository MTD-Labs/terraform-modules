data "archive_file" "prometheus_values" {
  count       = var.eks_enabled == true ? 1 : 0
  type        = "zip"
  source_file = "${var.values_file_path}/values-${var.env}.yaml"
  output_path = "/tmp/prometheus_helm_dir_checksum.zip"
}

resource "helm_release" "prometheus" {
  count            = var.eks_enabled == true ? 1 : 0
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "79.5.0"
  namespace        = "monitoring"
  create_namespace = true

  values = [templatefile("${var.values_file_path}/values-${var.env}.yaml", {
    subnets = join(",", var.subnets)
  })]

  depends_on = [data.archive_file.prometheus_values]

  # lifecycle {
  #   ignore_changes = [
  #     values,
  #     set
  #   ]
  # }
}
