terraform {
  required_version = "0.11.11"
}

provider "aws" {
  profile    = "work-user"
  region     = "eu-west-1"
}

module "consul" {
  source  = "hashicorp/consul/aws"
  version = "0.7.3"

  servers = 3
}

