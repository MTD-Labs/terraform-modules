data "archive_file" "grafana_values" {
  count       = var.eks_enabled == true ? 1 : 0
  type        = "zip"
  source_file = "${var.values_file_path}/values-${var.env}.yaml"
  output_path = "/tmp/grafana_helm_dir_checksum.zip"
}

resource "helm_release" "grafana" {
  count            = var.eks_enabled == true ? 1 : 0
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  version          = "8.8.5"
  namespace        = "monitoring"
  create_namespace = true

  values = [templatefile("${var.values_file_path}/values-${var.env}.yaml", {
    subnets = join(",", var.subnets)
    host    = var.host
  })]

  depends_on = [data.archive_file.grafana_values]

  # lifecycle {
  #   ignore_changes = [
  #     values,
  #     set
  #   ]
  # }
}
