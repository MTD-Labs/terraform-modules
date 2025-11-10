# # Create SecretStore in the application namespace using kubectl command
# resource "null_resource" "secretstore" {
#   count = var.eks_enabled == true ? 1 : 0

#   triggers = {
#     namespace = var.namespace
#     region    = var.region
#     manifest = yamlencode({
#       apiVersion = "external-secrets.io/v1beta1"
#       kind       = "SecretStore"
#       metadata = {
#         name      = "aws-secrets-manager"
#         namespace = var.namespace
#       }
#       spec = {
#         provider = {
#           aws = {
#             service = "SecretsManager"
#             region  = var.region
#             auth = {
#               jwt = {
#                 serviceAccountRef = {
#                   name      = "external-secrets"
#                   namespace = "external-secrets"
#                 }
#               }
#             }
#           }
#         }
#       }
#     })
#   }

#   provisioner "local-exec" {
#     command = "echo '${self.triggers.manifest}' | kubectl apply -f -"
#   }

#   provisioner "local-exec" {
#     when    = destroy
#     command = "kubectl delete secretstore aws-secrets-manager -n ${self.triggers.namespace} --ignore-not-found=true"
#   }
# }

# Install Helm application
resource "helm_release" "apps" {
  count            = var.eks_enabled == true ? 1 : 0
  name             = var.app_name
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://mtd-labs.github.io/helm-charts/"
  chart            = var.chart_name
  version          = var.chart_version

  values = [templatefile("${var.values_file_path}/values-${var.env}.yaml", {
    env          = var.env
    cluster_name = var.cluster_name
  })]

  cleanup_on_fail = true
}