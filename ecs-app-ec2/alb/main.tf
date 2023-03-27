resource "aws_lb" "frontend" {
  name                       = "${var.name}-alb-frontend-${var.environment}"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = var.alb_security_groups
  subnets                    = var.subnets
  enable_deletion_protection = false
  count                      = var.frontend ? 1 : 0
  tags = {
    Name        = "${var.name}-alb-frontend-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "frontend" {
  name                 = "${var.name}-tg-frontend-${var.environment}"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 120
  count                = var.frontend ? 1 : 0

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path_frontend
    unhealthy_threshold = "2"
  }

  tags = {
    Name        = "${var.name}-tg-frontend-${var.environment}"
    Environment = var.environment
  }
}

# Redirect to https listener
resource "aws_lb_listener" "frontendhttp" {
  load_balancer_arn = aws_lb.frontend[0].id
  port              = 80
  protocol          = "HTTP"
  count             = var.frontend ? 1 : 0
  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Redirect traffic to target group
resource "aws_lb_listener" "frontendhttps" {
  load_balancer_arn = aws_lb.frontend[0].id
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  certificate_arn   = var.alb_tls_cert_arn
  count             = var.frontend ? 1 : 0

  default_action {
    target_group_arn = aws_lb_target_group.frontend[0].id
    type             = "forward"
  }
}

resource "aws_lb" "backend" {
  name                       = "${var.name}-alb-backend-${var.environment}"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = var.alb_security_groups
  subnets                    = var.subnets
  enable_deletion_protection = false
  count                      = var.backend ? 1 : 0

  tags = {
    Name        = "${var.name}-alb-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "backend" {
  name                 = "${var.name}-tg-backend-${var.environment}"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 120
  count                = var.backend ? 1 : 0
  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = var.health_check_path_backend
    unhealthy_threshold = "2"
  }

  tags = {
    Name        = "${var.name}-tg-${var.environment}"
    Environment = var.environment
  }
}

# Redirect to https listener
resource "aws_lb_listener" "backendhttp" {
  load_balancer_arn = aws_lb.backend[0].id
  port              = 80
  protocol          = "HTTP"
  count             = var.backend ? 1 : 0
  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Redirect traffic to target group
resource "aws_lb_listener" "backendhttps" {
  load_balancer_arn = aws_lb.backend[0].id
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  certificate_arn   = var.alb_tls_cert_arn
  count             = var.backend ? 1 : 0

  default_action {
    target_group_arn = aws_lb_target_group.backend[0].id
    type             = "forward"
  }
}

output "aws_alb_target_group_arn_frontend" {
  value = aws_lb_target_group.frontend[0].arn
}

output "aws_alb_target_group_arn_backend" {
  value = aws_lb_target_group.backend[0].arn
}
