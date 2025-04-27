provider "aws" {
  region = var.region
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eks-karpenter-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# EKS Cluster
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.0"
  cluster_name    = "eks-karpenter-cluster"
  cluster_version = "1.29"

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id

  enable_irsa = true

  # Managed node group as baseline (system pods)
  eks_managed_node_groups = {
    baseline = {
      desired_size = 2
      min_size     = 2
      max_size     = 4

      instance_types = var.instance_type
      capacity_type  = "ON_DEMAND"
    }
  }
}

# Karpenter IAM Role
module "karpenter_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                         = "karpenter-controller-role"
  attach_karpenter_controller_policy = true
  cluster_name                      = module.eks.cluster_name
  oidc_provider_arn                 = module.eks.oidc_provider_arn
  service_account_namespace         = "karpenter"
  service_account_name              = "karpenter"
}

# Karpenter Helm Deployment
resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = "karpenter"
  repository = "https://charts.karpenter.sh"
  chart      = "karpenter"
  version    = "v0.35.2"

  create_namespace = true

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_irsa.iam_role_arn
  }

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = module.eks.node_iam_instance_profile_name
  }
}

# Auto-apply karpenter-nodepool.yaml after Karpenter and EKS are ready
resource "null_resource" "apply_karpenter_nodepool" {
  depends_on = [
    helm_release.karpenter,
    module.eks
  ]

  provisioner "local-exec" {
    command = <<EOT
      aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}
      kubectl apply -f ${path.module}/karpenter-nodepool.yaml
    EOT
  }
}
