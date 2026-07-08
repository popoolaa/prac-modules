provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    bucket = "myansibles3bucketnasa"
    key    = "bootstrap-github-oidc.tfstate"
    region = "us-east-1"
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.existing_oidc_provider_arn
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_repo}:pull_request",
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/master",
        "repo:${var.github_org}/${var.github_repo}:environment:development",
        "repo:${var.github_org}/${var.github_repo}:environment:production",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_terraform" {
  name               = "github-actions-terraform"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}

# Broad EC2/VPC access is pragmatic for this lab setup, since the network
# and sg modules touch VPCs, subnets, route tables, IGWs, and security
# groups, and the EKS node group launches EC2 instances under the hood.
# Tighten to a scoped custom policy before using this role against an
# account with other unrelated workloads.
resource "aws_iam_role_policy_attachment" "ec2_full" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

data "aws_iam_policy_document" "state_access" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket}"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}/*"]
  }
}

resource "aws_iam_role_policy" "state_access" {
  name   = "terraform-state-access"
  role   = aws_iam_role.github_actions_terraform.id
  policy = data.aws_iam_policy_document.state_access.json
}

data "aws_caller_identity" "current" {}

# EKS + ECR support for the containerized app. No AWS-managed policy covers
# "full EKS access" for the caller the way AmazonEC2FullAccess does for EC2,
# so this is eks:* on * — matches the same broad-but-single-repo-scoped
# trade-off as ec2_full above.
data "aws_iam_policy_document" "eks_management" {
  statement {
    effect    = "Allow"
    actions   = ["eks:*"]
    resources = ["*"]
  }

  # Lets Terraform create/manage the IAM roles the EKS cluster and node
  # group assume. iam:PassRole is the critical one here — without it,
  # CreateCluster/CreateNodegroup can't hand these roles off to
  # eks.amazonaws.com / ec2.amazonaws.com and will fail.
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dev-eks-cluster-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dev-eks-node-role",
    ]
  }

  # This account has never used EKS before. The very first cluster/node
  # group creation triggers AWS to auto-create
  # AWSServiceRoleForAmazonEKS(Nodegroup) — without this permission, that
  # first apply fails with a cryptic AccessDenied that's easy to miss.
  statement {
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::*:role/aws-service-role/*eks*"]
  }
}

resource "aws_iam_role_policy" "eks_management" {
  name   = "eks-management"
  role   = aws_iam_role.github_actions_terraform.id
  policy = data.aws_iam_policy_document.eks_management.json
}

# Covers both Terraform-time ECR repo management and the docker push/pull
# build-and-push.yml does at runtime, reusing this same OIDC role.
resource "aws_iam_role_policy_attachment" "ecr_full" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}
