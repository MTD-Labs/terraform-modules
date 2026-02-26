data "archive_file" "nginx_controller_values" {
  count       = var.eks_enabled == true ? 1 : 0
  type        = "zip"
  source_file = "${var.values_file_path}/values-${var.env}.yaml"
  output_path = "/tmp/nginx_controller_helm_dir_checksum.zip"
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  depends_on = [
    kubernetes_manifest.cloudflare_external_secret
  ]

  set = [
    {
      name  = "clusterName"
      value = var.cluster_name
    },
    {
      name  = "region"
      value = var.region
    },
    {
      name  = "vpcId"
      value = var.vpc_id
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    }
  ]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = "cert-manager"
  create_namespace = true

  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"

  set = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]
}

resource "kubernetes_manifest" "cloudflare_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "cloudflare-api-token-secret"
      namespace = "cert-manager"
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = var.cluster_secret_store_name
        kind = "ClusterSecretStore"
      }
      target = {
        name = "cloudflare-api-token-secret"
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "api-token"
          remoteRef = {
            key = var.cloudflare_api_secret_name
            property = "api-token"
          }
        }
      ]
    }
  }

  depends_on = [
    helm_release.cert_manager
  ]
}

resource "kubernetes_manifest" "cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-cloudflare"
    }
    spec = {
      acme = {
        email  = var.letsencrypt_email
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-cloudflare-private-key"
        }
        solvers = [{
          dns01 = {
            cloudflare = {
              apiTokenSecretRef = {
                name = "cloudflare-api-token-secret"
                key  = "api-token"
              }
            }
          }
        }]
      }
    }
  }

  depends_on = [
    kubernetes_manifest.cloudflare_external_secret
  ]
}

resource "helm_release" "nginx_controller" {
  count            = var.eks_enabled == true ? 1 : 0
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.14.3"
  namespace        = "nginx-controller"
  create_namespace = true

  values = [
    templatefile(
      "${var.values_file_path}/values-${var.env}.yaml",
      {
        subnets         = join(",", var.subnets)
        acm_arn         = aws_acm_certificate.ingress_certificate.arn
        security_groups = join(",", var.security_groups)
      }
    )
  ]
  depends_on = [
    data.archive_file.nginx_controller_values,
    helm_release.aws_lb_controller
  ]

  # Example to preserve custom overrides
  # lifecycle {
  #   ignore_changes = [
  #     values,
  #   ]
  # }
}
