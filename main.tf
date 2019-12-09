provider "aws" {
  region = "us-east-2"
}

resource "aws_launch_configuration" "example" {
  image_id   = "ami-0d03add87774b12c5"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
        #!/bin/bash
        echo "Hello World" > index.html
        nohup busybox httpd -f -p "${var.port}" &
        EOF

  lifecycle {
    create_before_destroy = true
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

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.id
  availability_zones = ["${data.aws_availability_zones.available.names}"]
  min_size = 2
  max_size = 3

  tag = {
    key   = "Name"
    value = "terraform_asg_example"
    propagate_at_launch = true
  }
}


variable "port" {
    description = "The port the server will use for HTTP requests"
    default = 8080
}

# output "public_ip" {
#   value = "${aws_instance.example.public_ip}"
#}
