resource "aws_iam_policy" "s3_env_access" {
  name        = "${var.name}-s3-env-access-${var.environment}"
  path        = "/"
  description = "s3 ecs env access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:s3:::${var.name}-env/*", "arn:aws:s3:::${var.name}-env"]
      },
      {
        Action = [
          "s3:GetBucketLocation",
        ]
        Effect   = "Allow"
        Resource = ["arn:aws:s3:::${var.name}-env"]
      }
    ]
  })
}


data "aws_iam_policy_document" "ecs_trust_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.name}-ec2-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecs_trust_policy.json
  tags = {
    "name"        = "${var.name}"
    "environment" = "${var.environment}"
  }
}


resource "aws_iam_instance_profile" "ec2_instance_role" {
  name = "${var.name}-ec2-instance-role-${var.environment}"
  role = aws_iam_role.ec2_role.name
  tags = {
    "name"        = "${var.name}"
    "environment" = "${var.environment}"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.name}-ecs-TaskExecutionRole-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.name}-ecs-TaskRole-${var.environment}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ec2-instance-role-role-policy-attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-cloudwatch" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-s3-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.s3_env_access.arn
}

resource "aws_iam_role_policy_attachment" "ecs-task-s3-policy-attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_env_access.arn
}

output "ecs_task_execution_role" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role" {
  value = aws_iam_role.ecs_task_role.arn
}

output "ec2_instance_role" {
  value = aws_iam_instance_profile.ec2_instance_role.name
}
