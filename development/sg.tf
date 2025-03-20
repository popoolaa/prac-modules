module "dev_sg_1" {
  source = "../modules/sg"
  vpc_name = module.dev_vpc_1.vpc_name
  vpc_id = module.dev_vpc_1.vpc_id
  ingress_value = ["80", "443", "445", "8080", "22", "3389"]
  environment = module.dev_vpc_1.environment
}
