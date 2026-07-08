#This Terraform Code Deploys Basic VPC Infra.
provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.dev_eks_1.cluster_endpoint
  cluster_ca_certificate = base64decode(module.dev_eks_1.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.dev.token
}

terraform {
  backend "s3" {
    bucket = "myansibles3bucketnasa"
    key    = "Development.tfstate"
    region = "us-east-1"
  }
}
