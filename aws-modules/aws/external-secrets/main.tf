########################################
# EXTERNAL SECRETS OPERATOR HELM CHART
########################################

resource "helm_release" "external_secrets" {
  count = var.install_external_secrets ? 1 : 0

  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_chart_version
  namespace        = "external-secrets"
  create_namespace = true

  set = [
    {
      name  = "installCRDs"
      value = "true"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.external_secrets_role_arn
    },
    {
      name  = "securityContext.fsGroup"
      value = "65534"
    }
  ]
  depends_on = [
    var.cluster_ready_dependency
  ]
}

# Wait for CRDs to be fully installed and ready
resource "time_sleep" "wait_for_crds" {
  count = var.install_external_secrets ? 1 : 0

  create_duration = "30s"

  depends_on = [
    helm_release.external_secrets
  ]
}

########################################
# SECRET STORE (AWS Secrets Manager)
########################################

resource "null_resource" "secret_store" {
  count = var.install_external_secrets && var.create_secret_store ? 1 : 0

  triggers = {
    secret_store_name      = var.secret_store_name
    secret_store_namespace = var.secret_store_namespace
    region                 = var.region
    manifest = yamlencode({
      apiVersion = "external-secrets.io/v1beta1"
      kind       = "SecretStore"
      metadata = {
        name      = var.secret_store_name
        namespace = var.secret_store_namespace
      }
      spec = {
        provider = {
          aws = {
            service = "SecretsManager"
            region  = var.region
            auth = {
              jwt = {
                serviceAccountRef = {
                  name = "external-secrets"
                }
              }
            }
          }
        }
      }
    })
  }

  provisioner "local-exec" {
    command = "echo '${self.triggers.manifest}' | kubectl apply -f -"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete secretstore ${self.triggers.secret_store_name} -n ${self.triggers.secret_store_namespace} --ignore-not-found=true"
  }

  depends_on = [
    time_sleep.wait_for_crds
  ]
}

########################################
# CLUSTER SECRET STORE (optional - for cluster-wide access)
########################################

resource "null_resource" "cluster_secret_store" {
  count = var.install_external_secrets && var.create_cluster_secret_store ? 1 : 0

  triggers = {
    cluster_secret_store_name = var.cluster_secret_store_name
    region                    = var.region
    manifest = yamlencode({
      apiVersion = "external-secrets.io/v1beta1"
      kind       = "ClusterSecretStore"
      metadata = {
        name = var.cluster_secret_store_name
      }
      spec = {
        provider = {
          aws = {
            service = "SecretsManager"
            region  = var.region
            auth = {
              jwt = {
                serviceAccountRef = {
                  name      = "external-secrets"
                  namespace = "external-secrets"
                }
              }
            }
          }
        }
      }
    })
  }

  provisioner "local-exec" {
    command = "echo '${self.triggers.manifest}' | kubectl apply -f -"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete clustersecretstore ${self.triggers.cluster_secret_store_name} --ignore-not-found=true"
  }

  depends_on = [
    time_sleep.wait_for_crds
  ]
}