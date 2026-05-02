terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "tf-state-cicd-harshvarshi"
    key    = "cicd-pipeline/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  environment = var.environment
  vpc_cidr    = var.vpc_cidr

  availability_zones = var.availability_zones
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets

  tags = var.common_tags
}

# ALB Module
module "alb" {
  source = "./modules/alb"

  environment = var.environment
  vpc_id      = module.vpc.vpc_id

  public_subnets        = module.vpc.public_subnet_ids
  alb_security_group_id = module.vpc.alb_security_group_id

  internal                   = false
  enable_deletion_protection = var.enable_deletion_protection

  health_check_path     = var.health_check_path
  health_check_interval = var.health_check_interval

  tags = var.common_tags
}

# ASG Module
module "asg" {
  source = "./modules/asg"

  environment = var.environment
  vpc_id      = module.vpc.vpc_id

  private_subnet_ids    = module.vpc.private_subnet_ids
  asg_security_group_id = module.vpc.asg_security_group_id

  ami_id        = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_pair_name = var.key_pair_name

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  target_group_arn = module.alb.target_group_arn

  user_data = var.user_data

  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  tags = var.common_tags
}

# CloudWatch Module
module "cloudwatch" {
  source = "./modules/cloudwatch"

  environment = var.environment

  asg_name             = module.asg.asg_name
  alb_target_group_arn = module.alb.target_group_arn

  sns_topic_arn = var.sns_topic_arn

  cpu_alarm_threshold    = var.cpu_alarm_threshold
  memory_alarm_threshold = var.memory_alarm_threshold

  tags = var.common_tags
}

# SNS Topic for Notifications
resource "aws_sns_topic" "notifications" {
  name = "${var.environment}-cicd-notifications"

  tags = var.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = length(var.notification_emails)
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.notification_emails[count.index]
}

# ECS resources used by the GitHub Actions deploy jobs.
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 14

  tags = var.common_tags
}

resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-cluster"
  })
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.environment}-${var.app_name}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.environment}-${var.app_name}-ecs-tasks-sg"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [module.vpc.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.app_name}-ecs-tasks-sg"
  })
}

resource "aws_lb_target_group" "ecs" {
  name        = "${var.environment}-${var.app_name}-ecs-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = var.health_check_interval
    path                = var.health_check_path
    matcher             = "200"
  }

  tags = merge(var.common_tags, {
    Name = "${var.environment}-${var.app_name}-ecs-tg"
  })
}

resource "aws_lb_listener_rule" "ecs" {
  listener_arn = module.alb.http_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.ecs_task_cpu)
  memory                   = tostring(var.ecs_task_memory)
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = var.container_image
      essential = true
      cpu       = var.ecs_task_cpu
      memory    = var.ecs_task_memory

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = "production"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = var.common_tags
}

resource "aws_ecs_service" "prod" {
  name            = "prod-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.ecs_prod_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs.arn
    container_name   = var.app_name
    container_port   = var.container_port
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution,
    aws_lb_listener_rule.ecs
  ]

  tags = merge(var.common_tags, {
    Name = "prod-service"
  })
}

resource "aws_ecs_service" "staging" {
  name            = "staging-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.ecs_staging_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution
  ]

  tags = merge(var.common_tags, {
    Name = "staging-service"
  })
}
