# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

# ALB Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "target_group_arn" {
  description = "ARN of the ALB target group"
  value       = module.alb.target_group_arn
}

# ASG Outputs
output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.asg.asg_name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = module.asg.asg_arn
}

# SNS Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic for notifications"
  value       = aws_sns_topic.notifications.arn
}

# CloudWatch Outputs
output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = module.cloudwatch.log_group_name
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster used by the CI/CD pipeline"
  value       = aws_ecs_cluster.main.name
}

output "ecs_prod_service_name" {
  description = "Name of the production ECS service"
  value       = aws_ecs_service.prod.name
}

output "ecs_staging_service_name" {
  description = "Name of the staging ECS service"
  value       = aws_ecs_service.staging.name
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_target_group_arn" {
  description = "ARN of the ECS target group"
  value       = aws_lb_target_group.ecs.arn
}
