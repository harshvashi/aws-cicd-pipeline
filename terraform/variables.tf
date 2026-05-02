# AWS Region
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# Environment
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for the VPC"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

# ALB Configuration
variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "Health check path for ALB"
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

# EC2 Configuration
variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_pair_name" {
  description = "SSH key pair name"
  type        = string
  default     = ""
}

variable "user_data" {
  description = "User data script for EC2 instances"
  type        = string
  default     = ""
}

# Auto Scaling Configuration
variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 10
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 3
}

variable "health_check_type" {
  description = "Health check type (EC2 or ELB)"
  type        = string
  default     = "ELB"
}

variable "health_check_grace_period" {
  description = "Health check grace period in seconds"
  type        = number
  default     = 300
}

# CloudWatch Configuration
variable "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
  default     = ""
}

variable "notification_emails" {
  description = "Email addresses for SNS notifications"
  type        = list(string)
  default     = []
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for alarm (%)"
  type        = number
  default     = 80
}

variable "memory_alarm_threshold" {
  description = "Memory utilization threshold for alarm (%)"
  type        = number
  default     = 80
}

# ECS Configuration
variable "app_name" {
  description = "Application name used for ECS resources"
  type        = string
  default     = "my-app"
}

variable "container_image" {
  description = "Initial container image for ECS task definitions"
  type        = string
  default     = "885000707645.dkr.ecr.us-east-1.amazonaws.com/my-app:latest"
}

variable "container_port" {
  description = "Container port exposed by the application"
  type        = number
  default     = 3000
}

variable "ecs_task_cpu" {
  description = "CPU units for the ECS Fargate task"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory in MiB for the ECS Fargate task"
  type        = number
  default     = 512
}

variable "ecs_prod_desired_count" {
  description = "Desired task count for the production ECS service"
  type        = number
  default     = 1
}

variable "ecs_staging_desired_count" {
  description = "Desired task count for the staging ECS service"
  type        = number
  default     = 0
}

# Common Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "cicd-pipeline"
    ManagedBy = "terraform"
  }
}
