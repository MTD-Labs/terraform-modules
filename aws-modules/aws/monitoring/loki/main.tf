data "aws_caller_identity" "current" {
  count = var.eks_enabled == true ? 1 : 0

}

resource "aws_s3_bucket" "loki_bucket" {
  count  = var.eks_enabled == true ? 1 : 0
  bucket = var.loki_bucket_name

  # Optional settings like versioning, encryption, etc., can go here.
  # versioning {
  #   enabled = true
  # }
}
data "aws_iam_policy_document" "loki_s3" {
  count = var.eks_enabled == true ? 1 : 0
  statement {
    sid    = "LokiStorage"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::${var.loki_bucket_name}",
      "arn:aws:s3:::${var.loki_bucket_name}/*"
    ]
  }
}

resource "aws_iam_policy" "loki_s3_policy" {
  count  = var.eks_enabled == true ? 1 : 0
  name   = "LokiS3AccessPolicy-${var.env}"
  policy = data.aws_iam_policy_document.loki_s3[0].json
}

data "template_file" "loki_trust_policy" {
  template = file("${path.module}/policies/trust-policy.json")
  count    = var.eks_enabled == true ? 1 : 0
  vars = {
    cluster_oidc_id = var.cluster_oidc_id
    account_id      = data.aws_caller_identity.current[0].account_id
    region          = var.region
  }
}


resource "aws_iam_role" "loki_role" {
  count              = var.eks_enabled == true ? 1 : 0
  name               = "LokiServiceAccountRole-${var.env}"
  assume_role_policy = data.template_file.loki_trust_policy[0].rendered
}

resource "aws_iam_role_policy_attachment" "loki_s3_attachment" {
  count      = var.eks_enabled == true ? 1 : 0
  role       = aws_iam_role.loki_role[0].name
  policy_arn = aws_iam_policy.loki_s3_policy[0].arn
}


data "archive_file" "loki_values" {
  count       = var.eks_enabled == true ? 1 : 0
  type        = "zip"
  source_file = "${var.values_file_path}/values-${var.env}.yaml"
  output_path = "/tmp/loki_helm_dir_checksum.zip"
}

resource "helm_release" "loki" {
  count            = var.eks_enabled == true ? 1 : 0
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = "6.25.0"
  namespace        = "monitoring"
  create_namespace = true

  values = [templatefile("${var.values_file_path}/values-${var.env}.yaml", {
    env              = var.env
    cluster_name     = var.cluster_name
    loki_bucket_name = var.loki_bucket_name
    region           = var.region
  })]

  set = [
    # common SA (if used by some pods)
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.loki_role[0].arn
    },

    # per-component SAs (add what you actually deploy)
    {
      name  = "compactor.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.loki_role[0].arn
    },
    {
      name  = "backend.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.loki_role[0].arn
    },
    {
      name  = "read.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.loki_role[0].arn
    },
    {
      name  = "write.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = aws_iam_role.loki_role[0].arn
    }
  ]

  depends_on = [data.archive_file.loki_values]

  lifecycle {
    ignore_changes = [
      values,
      set
    ]
  }
}
