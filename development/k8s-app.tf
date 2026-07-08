data "aws_eks_cluster_auth" "dev" {
  name = module.dev_eks_1.cluster_name
}

module "dev_app_1" {
  source               = "../modules/k8s-app"
  image_repository_url = module.dev_ecr_1.repository_url
  image_tag            = "dev"

  depends_on = [module.dev_eks_1]
}
