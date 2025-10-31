data "aws_caller_identity" "current" {
  count = var.eks_enabled == true ? 1 : 0
}

data "archive_file" "promtail_values" {
  count       = var.eks_enabled == true ? 1 : 0
  type        = "zip"
  source_file = "${var.values_file_path}/values-${var.env}.yaml"
  output_path = "/tmp/promtail_helm_dir_checksum.zip"
}

resource "helm_release" "promtail" {
  count            = var.eks_enabled == true ? 1 : 0
  name             = "promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  version          = "6.16.0"
  namespace        = "monitoring"
  create_namespace = true

  values = [templatefile("${var.values_file_path}/values-${var.env}.yaml", {
    tenant_id = var.tenant_id
  })]

  depends_on = [data.archive_file.promtail_values]

  lifecycle {
    ignore_changes = [
      values,
      set
    ]
  }
}
