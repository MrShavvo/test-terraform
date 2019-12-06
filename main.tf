provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "example" {
  ami   = "ami-0d03add87774b12c5"
  instance_type = "t2.micro"

  tags = {
      Name = "terraform-example"
  }
}
