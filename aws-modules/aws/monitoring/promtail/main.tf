provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_cert)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", var.cluster_name, "--output=json"]
  }
}

provider "helm" {
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_cert)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--output=json"]
    }
  }
}

data "aws_caller_identity" "current" {
  count  = var.eks_enabled == true ? 1 : 0
}

data "archive_file" "promtail_values" {
  count  = var.eks_enabled == true ? 1 : 0
  type        = "zip"
  source_file = "${var.values_file_path}/values-${var.env}.yaml"
  output_path = "/tmp/promtail_helm_dir_checksum.zip"
}

resource "helm_release" "promtail" {
  count  = var.eks_enabled == true ? 1 : 0
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
