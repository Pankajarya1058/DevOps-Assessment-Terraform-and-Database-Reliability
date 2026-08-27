# Separate state per environment - different bucket key (and optionally a
# different bucket/account entirely for stronger prod isolation).
# `terraform init` will prompt to migrate state if you change this later.

terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state"
    key            = "myapp/dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks-dev"
    encrypt        = true
  }
}
