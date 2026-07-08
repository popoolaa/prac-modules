module "dev_eks_1" {
  source               = "../modules/eks"
  cluster_name         = "dev-eks"
  environment          = module.dev_vpc_1.environment
  vpc_id               = module.dev_vpc_1.vpc_id
  cluster_subnet_ids   = concat(module.dev_vpc_1.public-subnet, module.dev_vpc_1.private-subnet)
  public_subnet_ids    = module.dev_vpc_1.public-subnet
  extra_sg_id          = module.dev_sg_1.sg_id
  kubernetes_version   = var.kubernetes_version
  admin_principal_arns = var.admin_principal_arns
}
