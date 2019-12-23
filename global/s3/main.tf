provider "aws" {
  region = "us-east-2"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "shavvos-terraform-up-and-running-state"

  #Enable versioning for full history of state files
  versioning {
      enabled = true
  }
  # prevents accidental deletion
  lifecycle {
      prevent_destroy = true
  }

  #Enable server side encryption
  server_side_encryption_configuration  {
    rule  {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
#creates a dynamodb table for state file locking
resource "aws_dynamodb_table" "terraform_locks" {
  name          = "terraform-up-and-running-locks"
  billing_mode  = "PAY_PER_REQUEST"
  hash_key      = "LockID"

  attribute {
    name  = "LockID"
    type  = "S"
  }
}

#configures backend for terraform to pull the state file from
#partial configuration. uses backend.hcl to pull other settings 
#from `terraform init` with -backend-config
terraform {
  backend "s3" {
    bucket          =   "shavvos-terraform-up-and-running-state"
    region          =   "us-east-2"
    dynamodb_table  =   "terraform-up-and-running-locks"
    encrypt         =   true
    key             =   "global/s3/terraform.tfstate"
  }
}