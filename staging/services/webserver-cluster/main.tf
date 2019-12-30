provider "aws" {
  region = "us-east-2"
}

#pulls default vpc region
data "aws_vpc" "default" {
  default = true
}

#looks up subnets within default vpc
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

#resource "<provider>_<type>" "<name>"

#launch configuration which specifies how to configure each ec2 instance in the asg
resource "aws_launch_configuration" "example" {
  image_id   = "ami-0d03add87774b12c5"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = data.template_file.user_data.rendered
  lifecycle {
    create_before_destroy = true
  }
}

#security group to allow traffic to instances
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

#creates an ALB
resource "aws_lb" "example" {
  name                = "terraform-asg-example"
  load_balancer_type  = "application"
  subnets             = data.aws_subnet_ids.default.ids
  security_groups     = [aws_security_group.alb.id]
}

#listener to configure the ALB
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80 #default http port
  protocol          = "HTTP" #http as the protocol

  #By default, return a simple 404 page
  default_action {
    type  = "fixed-response"

    fixed_response {
      content_type  = "text/plain"
      message_body  = "404: page not found"
      status_code   = 404
    }
  }
}

#security group to allow incoming and outgoing requests on the ALB
resource "aws_security_group" "alb" {
  name  = "terraform-example-alb"

  #allow inbound HTTP requests
  ingress {
    from_port     = 80
    to_port       = 80
    protocol      = "tcp"
    cidr_blocks   = ["0.0.0.0/0"]
  }

  #allow all outbound requests
  egress  {
    from_port     = 0
    to_port       = 0
    protocol      = "-1"
    cidr_blocks   = ["0.0.0.0/0"]
  }
}

#target group with healthcheck
resource "aws_lb_target_group" "asg" {
  name      = "terraform-asg-example"
  port      = var.port
  protocol  = "HTTP"
  vpc_id    = data.aws_vpc.default.id

  health_check  {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

#asg responsible for creating ec2 instances
resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.id
  vpc_zone_identifier = data.aws_subnet_ids.default.ids

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 3

  tag {
    key   = "Name"
    value = "terraform_asg_example"
    propagate_at_launch = true
  }
}

#Add a listener rule to send requests that match any path to the target group that contains the ASG
resource "aws_lb_listener_rule" "asg" {
  listener_arn  = aws_lb_listener.http.arn
  priority      = 100

  condition {
    field   = "path-pattern"
    values  = ["*"]
  }

  action  {
    type              = "forward"
    target_group_arn  = aws_lb_target_group.asg.arn
  }
}

terraform {
  backend "s3" {
    bucket          =   "shavvos-terraform-up-and-running-state"
    region          =   "us-east-2"
    dynamodb_table  =   "terraform-up-and-running-locks"
    encrypt         =   true
    key             =   "staging/services/webserver-cluster/terraform.tfstate"
  }
}

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket  = "shavvos-terraform-up-and-running-state"
    key     = "staging/data-stores/mysql/terraform.tfstate"
    region  = "us-east-2"
  }
}

data "template_file" "user_data" {
  template  = file("user-data.sh")

  vars  = {
    server_port = var.port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  }
}