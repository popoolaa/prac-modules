variable "cluster_name" {}
variable "environment" {}
variable "vpc_id" {}

# Combined public + private subnet IDs, passed to the EKS control plane's
# vpc_config. The control plane needs visibility into both, even though the
# node group itself only launches into the public subnets (see node_group.tf).
variable "cluster_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

# The dev_sg_1 / prod_sg_1 security group id, reused here instead of
# creating a dedicated third SG module call for the node group.
variable "extra_sg_id" {}

# No default: EKS standard support for a given minor version runs out after
# roughly 14 months, after which it silently flips into "extended support"
# at ~6x the control-plane hourly cost. Check
# `aws eks describe-cluster-versions --query "clusterVersions[?status=='standard']"`
# (or the AWS EKS release notes) at apply time and pass a currently-supported
# version explicitly from the root config — don't let this default silently.
variable "kubernetes_version" {
  type = string
}

# IAM principals (your own user/role ARN) granted cluster-admin via an EKS
# Access Entry, so you can `kubectl` in for verification. The CI role that
# creates the cluster gets bootstrap admin automatically; your own identity
# does not, under authentication_mode = "API".
variable "admin_principal_arns" {
  type    = list(string)
  default = []
}
