variable "namespace" {
  default = "app"
}

variable "image_repository_url" {}

# Floating tag (e.g. "dev" / "prod"), not a sha — required so pods keep
# retrying the pull and self-heal once build-and-push.yml pushes real
# content under the same tag, without a second `terraform apply`.
variable "image_tag" {}

variable "replicas" {
  default = 2
}

variable "node_port" {
  default = 30080
}
