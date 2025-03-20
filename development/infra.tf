module "dev_vpc_1" {
  source             = "../modules/network"
  vpc_cidr           = "10.90.0.0/16"
  vpc_name           = "dev_vpc_1"
  environment        = "Development"
  public_cidr_block  = ["10.90.1.0/24", "10.90.2.0/24", "10.90.3.0/24"]
  private_cidr_block = ["10.90.10.0/24", "10.90.20.0/24", "10.90.30.0/24"]
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }