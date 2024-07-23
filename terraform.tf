terraform {
  backend "s3" {
    bucket  = "netluna-co-devops-state"
    key     = "cloud/mvp/terraform-aws-s3-antivirus/terraform.tfstate"
    region  = "us-east-1"
    profile = "netluna"
  }
}
