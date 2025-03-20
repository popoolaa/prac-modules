module "prod_vpc_1" {
  source             = "../modules/network"
  vpc_cidr           = "192.168.0.0/16"
  vpc_name           = "prod_vpc_1"
  environment        = "Production"
  public_cidr_block  = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24"]
  private_cidr_block = ["192.168.10.0/24", "192.168.20.0/24", "192.168.30.0/24"]
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }