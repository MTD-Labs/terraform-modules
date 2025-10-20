########################################
# EKS CLUSTER (your original content)
########################################

data "aws_caller_identity" "current" {}

locals {
  tags = merge(
    {
      Name       = var.cluster_name
      Env        = var.env
      tf-managed = true
      tf-module  = "aws/eks"
    },
    var.tags
  )
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.vpc_subnets
    endpoint_private_access = var.endpoint_private
    endpoint_public_access  = var.endpoint_public
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  kubernetes_network_config {
    service_ipv4_cidr = var.service_ipv4_cidr
  }

  enabled_cluster_log_types = var.enabled_logs

  tags = local.tags
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.cluster_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
  tags               = local.tags
}

data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-eks-cluster-sg"
  description = "EKS cluster communication with worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description = "EKS control plane communication"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.vpc_private_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = var.vpc_subnets

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  instance_types = var.instance_types

  tags = local.tags
}

resource "aws_iam_role" "eks_node" {
  name               = "${var.cluster_name}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
  tags               = local.tags
}

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


########################################
# IRSA / OIDC PROVIDER (NEW)
########################################

# 1) Derive issuer pieces cleanly
locals {
  oidc_issuer   = aws_eks_cluster.this.identity[0].oidc[0].issuer # e.g. https://oidc.eks.me-south-1.amazonaws.com/id/1EE48D00...
  oidc_hostpath = replace(local.oidc_issuer, "https://", "")       # e.g. oidc.eks.me-south-1.amazonaws.com/id/1EE48D00...
  oidc_id       = element(split("/id/", local.oidc_issuer), 1)     # e.g. 1EE48D00...
}

# 2) Pull TLS thumbprint for the OIDC provider
data "tls_certificate" "eks_oidc" {
  url = local.oidc_issuer
}

# 3) Create (or manage) the IAM OIDC provider for this cluster
resource "aws_iam_openid_connect_provider" "eks" {
  url             = local.oidc_issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = local.tags
}


########################################
# EBS CSI DRIVER (ADD-ON + IRSA ROLE) (NEW)
########################################

# IRSA role for the aws-ebs-csi-driver controller:
# The service account used by the addon is: kube-system:ebs-csi-controller-sa
data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
    # lock it down to the SA name/namespace the addon uses:
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_irsa" {
  name               = "${var.cluster_name}-ebs-csi-irsa"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
  tags               = local.tags
}

# Managed AWS policy granting EBS CSI permissions
resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.ebs_csi_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Install the official EKS add-on and bind to the IRSA role
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  # You can pin a version if desired, e.g. "v1.30.0-eksbuild.1"
  # addon_version             = var.ebs_csi_addon_version
  service_account_role_arn    = aws_iam_role.ebs_csi_irsa.arn
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = local.tags

  depends_on = [
    aws_eks_node_group.default,
    aws_iam_role_policy_attachment.ebs_csi_policy
  ]
}
