variable "aws_region" {
  default = "us-east-1"
}

variable "github_org" {
  default = "popoolaa"
}

variable "github_repo" {
  default = "prac-modules"
}

variable "state_bucket" {
  default = "myansibles3bucketnasa"
}

variable "create_oidc_provider" {
  description = "Set to false if a GitHub OIDC provider already exists in this AWS account (only one is allowed per account)."
  default     = true
}

variable "existing_oidc_provider_arn" {
  description = "Used only when create_oidc_provider = false."
  default     = ""
}
