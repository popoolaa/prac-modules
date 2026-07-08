module "dev_ecr_1" {
  source          = "../modules/ecr"
  repository_name = "dev-secops-game"
  environment     = module.dev_vpc_1.environment
}
