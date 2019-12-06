provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "example" {
  ami   = "ami-0dacb0c129b49f529"
  instance_type = "t2.micro"

  tags = {
      Name = "terraform-example"
  }
}
