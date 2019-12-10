provider "aws" {
  region = "us-east-2"
}

data "aws_availability_zones" "available" {
  state = "available"
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

resource "aws_elb" "example" {
  name  = "terraform-asg-example"
  availability_zones = ["${data.aws_availability_zones.available.names[0]}"]
  security_groups    = ["${aws_security_group.elb.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = var.port
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 60
    target              = "HTTP:${var.port}/"
  }
}

resource "aws_security_group" "elb" {
  name  = "terraform-example-elb"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.id
  availability_zones = ["${data.aws_availability_zones.available.names[0]}"]

  load_balancers    = ["${aws_elb.example.name}"]
  health_check_type = "ELB"

  min_size = 2
  max_size = 3

  tag {
    key   = "Name"
    value = "terraform_asg_example"
    propagate_at_launch = true
  }
}


variable "port" {
    description = "The port the server will use for HTTP requests"
    default = 8080
}

output "elb_dns_name" {
  value = "${aws_elb.example.dns_name}"
}
