provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "example" {
  ami   = "ami-0d03add87774b12c5"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.instance.id}"]

#problem with variable
  user_data = <<-EOF
        #!/bin/bash
        echo "Hello World" > index.html
        nohup busybox httpd -f -p "${var.port}" &
        EOF

  tags = {
      Name = "terraform-example"
  }
}

resource "aws_security_group" "instance" {
    name = "terraform-example-instance"

    ingress {
        from_port   = var.port
        to_port     = var.port
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
  
}

variable "port" {
    description = "The port the server will use for HTTP requests"
    default = 8081
}

output "public_ip" {
  value = "${aws_instance.example.public_ip}"
}
