provider "aws" {
    region = "us-east-2"
}

resource "aws_db_instance" "example" {
  identifier_prefix     = "terraform-up-and-running"
  engine                = "mysql"
  allocated_storage     = 10
  instance_class        = "db.t2.micro"
  name                  = "example_database"
  username              = "admin"

  #pull password from aws secrets manager
  #password              = data.aws_secretsmanager_secret_version.db_password.secret_string
}

# data "aws_secretsmanager_secret_version" "db_password" {
#     secret_id = "mysql-master-password-stage"
# }

terraform {
  backend "s3" {
    bucket    = "shavvos-terraform-up-and-running-state"
    key       = "staging/data-stores/mysql/terraform.tfstate"
    region    = "us-east-2"

    dynamodb_table  = "terraform-up-and-running-locks"
    encrypt         = true
  }
}