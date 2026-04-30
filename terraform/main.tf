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

  public_subnets           = module.vpc.public_subnet_ids
  alb_security_group_id    = module.vpc.alb_security_group_id

  internal                 = false
  enable_deletion_protection = var.enable_deletion_protection

  health_check_path        = var.health_check_path
  health_check_interval    = var.health_check_interval

  tags = var.common_tags
}

# ASG Module
module "asg" {
  source = "./modules/asg"

  environment = var.environment
  vpc_id      = module.vpc.vpc_id

  private_subnet_ids       = module.vpc.private_subnet_ids
  asg_security_group_id    = module.vpc.asg_security_group_id

  ami_id                   = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type            = var.instance_type
  key_pair_name            = var.key_pair_name

  min_size                 = var.min_size
  max_size                 = var.max_size
  desired_capacity         = var.desired_capacity

  target_group_arn         = module.alb.target_group_arn

  user_data                = var.user_data

  health_check_type        = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  tags = var.common_tags
}

# CloudWatch Module
module "cloudwatch" {
  source = "./modules/cloudwatch"

  environment = var.environment

  asg_name                  = module.asg.asg_name
  alb_target_group_arn      = module.alb.target_group_arn

  sns_topic_arn             = var.sns_topic_arn

  cpu_alarm_threshold       = var.cpu_alarm_threshold
  memory_alarm_threshold    = var.memory_alarm_threshold

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