output "rendered_yaml" {
  value = templatefile("${var.values_file_path}/values-${var.env}.yaml", {
    subnets = join(",", var.subnets)
    acm_arn = var.acm_arn
    host    = var.host
  })
}
