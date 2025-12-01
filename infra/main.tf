provider "aws" {
  region = "us-west-2"
}
data "aws_vpc" "default" {
  id = var.vpc_id
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_ecr_authorization_token" "token" {}

locals {
  ecr_registry = split("https://", data.aws_ecr_authorization_token.token.proxy_endpoint)[1]
}

resource "aws_ecs_cluster" "main" {
  name = "hello-world-cluster-${var.environment}"
}


resource "aws_security_group" "alb" {
  name        = "alb-sg-${var.environment}"
  description = "ALB security group"
  vpc_id      = data.aws_vpc.default.id

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

resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-sg-${var.environment}"
  description = "Security group for ECS tasks"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_lb" "main" {
  name               = "hello-alb-${var.environment}"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "main" {
  name        = "hello-tg-${var.environment}"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "hello-world-${var.environment}"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"

  execution_role_arn = aws_iam_role.ecs_task_exec.arn
  task_role_arn      = aws_iam_role.ecs_task_exec.arn

  container_definitions = jsonencode([
    {
      name      = "hello-world"
      image     = "${local.ecr_registry}/hello-world-app-${var.environment}:${var.image_tag}"
      essential = true
      portMappings = [
      {
        containerPort = 8000
        hostPort      = 8000
        protocol      = "tcp"
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/hello-world-app-${var.environment}"
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
  }
])
}

resource "aws_ecs_service" "app" {
  name            = "hello-service-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = data.aws_subnets.default.ids
    security_groups = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "hello-world"
    container_port   = 8000
  }

  depends_on = [
    aws_lb_listener.main
  ]
}

resource "aws_iam_role" "ecs_task_exec" {
  name = "ecsTaskExecutionRole-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/hello-world-app-${var.environment}"
  retention_in_days = 30
}
