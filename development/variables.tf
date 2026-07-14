variable "aws_region" {}

# IAM principals granted cluster-admin on the EKS cluster via an Access
# Entry. Only the identity that actually called CreateCluster gets
# bootstrap admin automatically — whichever of local `deepops` or the CI
# role (github-actions-terraform) applies first "wins" that, so both need
# to be listed explicitly here to guarantee access regardless of who ends
# up creating/re-creating the cluster.
variable "admin_principal_arns" {
  type = list(string)
  default = [
    "arn:aws:iam::900060399717:user/deepops",
    "arn:aws:iam::900060399717:role/github-actions-terraform",
  ]
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