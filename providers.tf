terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.52.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
  default_tags {
    tags = {
      Project = "${var.project}"
      Owner   = "${var.profile}"
      DC      = "${var.region}"
    }
  }
}
