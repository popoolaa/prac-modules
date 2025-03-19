#This Terraform Code Deploys Basic VPC Infra.
provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    bucket = "myansibles3bucketnasa"
    key    = "Development.tfstate"
    region = "us-east-1"
  }
}