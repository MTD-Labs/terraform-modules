provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_cert)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

data "archive_file" "nginx_controller_values" {
  type        = "zip"
  source_file = "${var.values_file_path}/values-${var.env}.yaml"
  output_path = "/tmp/nginx_controller_helm_dir_checksum.zip"
}

resource "helm_release" "nginx_controller" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.12.0"
  namespace        = "nginx-controller"
  create_namespace = true

  values = [
    templatefile(
      "${var.values_file_path}/values-${var.env}.yaml",
      {
        subnets = join(",", var.subnets)
        acm_arn = aws_acm_certificate.ingress_certificate.arn
        security_groups = join(",", var.security_groups)
      }
    )
  ]
  depends_on = [
    data.archive_file.nginx_controller_values
  ]

  # Example to preserve custom overrides
  # lifecycle {
  #   ignore_changes = [
  #     values,
  #   ]
  # }
}
