data "aws_vpc" "vpc" {
  id = var.vpc_id
}
# Internet to ALB
resource "aws_security_group" "alb" {
  name        = "${var.name}-sg-alb-${var.environment}"
  vpc_id      = var.vpc_id
  description = "loadbalancer sg"

  ingress {
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.name}-sg-alb-${var.environment}"
    Environment = var.environment
  }
}



resource "aws_security_group_rule" "ec2_alb" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 1024
  to_port                  = 65535
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.ec2.id
  depends_on = [
    aws_security_group.ec2
  ]
}


resource "aws_security_group" "ec2" {
  name        = "${var.name}-sg-ec2-${var.environment}"
  vpc_id      = var.vpc_id
  description = "ec2 sg"


  ingress {
    protocol        = "tcp"
    from_port       = 1024
    to_port         = 65535
    security_groups = ["${aws_security_group.alb.id}"]
  }

  ingress {
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    protocol         = "-1"
    from_port        = 0
    to_port          = 0
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.name}-sg-ec2-${var.environment}"
    Environment = var.environment
  }

}


output "ec2" {
  value = aws_security_group.ec2.id
}

output "alb" {
  value = aws_security_group.alb.id
}
