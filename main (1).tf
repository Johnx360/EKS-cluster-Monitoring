variable "region" {
  default = "eu-north-1"
}

variable "cluster_name" {
  default = "my-5EKS-cluster"
}

variable "availability_zones" {
  type = list(string)
  default = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
}

variable "private_subnets_cidrs" {
  type = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets_cidrs" {
  type = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "4.0.1"

  name = var.cluster_name
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway  = true
  enable_dns_hostnames = true

  # Enable auto-assigning public IP addresses to instances launched in the subnets
  map_public_ip_on_launch = true
}

resource "aws_security_group" "worker_group_mgmt_one" {
  name_prefix = "worker_group_mgmt_one"
  description = "worker_group_mgmt_one"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "worker_group_mgmt_one" {
  security_group_id = aws_security_group.worker_group_mgmt_one.id

  type        = "ingress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/8", "95.136.121.65/32"]
}

resource "kubernetes_secret" "terraform_token" {
  metadata {
    name      = "terraform-token"
    namespace = "kube-system"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.terraform.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"

  data = {
    "my-custom-data" = "my-custom-value"
  }

  depends_on = [
    kubernetes_service_account.terraform,
  ]
}

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "19.13.1"

  cluster_name = var.cluster_name
  subnet_ids   = module.vpc.public_subnets

  tags = {
    Terraform          = "true"
    KubernetesCluster  = var.cluster_name
  }

  vpc_id = module.vpc.vpc_id

  # Add the following lines
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true

  eks_managed_node_groups = {
    default = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1

      instance_types = ["t3.large"]
      additional_tags = {
        Terraform          = "true"
        KubernetesCluster  = var.cluster_name
      }
    }
  }
}

resource "null_resource" "update_kubeconfig" {
  depends_on = [module.eks] # Add this line

  triggers = {
    cluster_id = module.eks.cluster_id
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} --kubeconfig kubeconfig.yaml"
  }
}

provider "kubernetes" {
  alias = "bootstrap"

  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_service_account" "terraform" {
  automount_service_account_token = true
  metadata {
    name      = "terraform"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "terraform" {
  provider = kubernetes.bootstrap

  metadata {
    name = "terraform"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.terraform.metadata[0].name
    namespace = kubernetes_service_account.terraform.metadata[0].namespace
  }
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  depends_on = [
    kubernetes_namespace.monitoring,
  ]

  set {
    name  = "prometheus.service.type"
    value = "LoadBalancer"
  }

  set {
  name  = "server.ingress.enabled"
  value = "true"
}

set {
  name  = "server.ingress.hosts[0].name"
  value = "prometheus.fogbyte.services"
}

set {
  name  = "server.ingress.hosts[0].path"
  value = "/"
}
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = "monitoring"
  depends_on = [
    kubernetes_namespace.monitoring,
  ]

  values = [
    <<-EOT
    service:
      type: LoadBalancer
    ingress:
      enabled: true
      hosts:
        - grafana.fogbyte.services
      paths:
        - /
    EOT
  ]
}

resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"

  set {
    name  = "enableVolumeScheduling"
    value = "true"
  }

  set {
    name  = "enableVolumeResizing"
    value = "true"
  }

  set {
    name  = "enableVolumeSnapshot"
    value = "true"
  }

  set {
    name  = "region"
    value = var.region
  }
}

resource "kubernetes_storage_class" "ebs_gp3" {
  metadata {
    name = "ebs-gp3"
  }
  storage_provisioner = "ebs.csi.aws.com"

  parameters = {
    type = "gp3"
  }

  reclaim_policy = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
}

resource "helm_release" "alertmanager" {
  name       = "alertmanager"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "alertmanager"
  namespace  = "monitoring"
  depends_on = [
    kubernetes_namespace.monitoring,
  ]

  values = [
    <<-EOT
      alertmanager:
        tolerations:
        - key: "node.kubernetes.io/not-ready"
          operator: "Exists"
          effect: "NoExecute"
          tolerationSeconds: 300
    EOT
  ]

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
  name  = "server.ingress.enabled"
  value = "true"
}

set {
  name  = "server.ingress.hosts[0].name"
  value = "alertmanager.fogbyte.services"
}

set {
  name  = "server.ingress.hosts[0].path"
  value = "/"
}
}

output "eks_cluster_id" {
  description = "The name/id of the EKS cluster."
  value       = module.eks.cluster_id
}

output "eks_cluster_security_group_id" {
  description = "The security group ID attached to the EKS cluster."
  value       = module.eks.cluster_security_group_id
}

output "aws_auth_configmap_yaml" {
  description = "The Kubernetes ConfigMap in YAML format."
  value       = module.eks.aws_auth_configmap_yaml
}
