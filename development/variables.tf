variable "aws_region" {}

# IAM principals (your own IAM user/role ARN) granted cluster-admin on the
# EKS cluster via an Access Entry, so you can `aws eks update-kubeconfig` +
# `kubectl` in for verification. Leave empty and only the CI role (which
# gets bootstrap admin automatically as the cluster creator) can access it.
variable "admin_principal_arns" {
  type    = list(string)
  default = ["arn:aws:iam::900060399717:user/deepops"]
}

# EKS standard support for a minor version runs out ~14 months after
# release; past that it silently flips to extended support at ~6x the
# control-plane hourly cost. Verify this is still in standard support
# (`aws eks describe-cluster-versions --query "clusterVersions[?status=='standard']"`)
# before every apply and bump it if not — do not assume this default is current.
variable "kubernetes_version" {
  type    = string
  default = "1.31"
}