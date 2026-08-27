# Separate state per environment. Consider using a distinct AWS account
# for prod entirely; at minimum this uses its own state key and lock table
# so a dev apply can never touch prod state.

terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state"
    key            = "myapp/prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks-prod"
    encrypt        = true
  }
}
