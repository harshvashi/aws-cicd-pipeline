# End-to-End CI/CD Pipeline on AWS

This project implements a fully automated CI/CD pipeline that takes application code from a Git commit all the way to a live deployment on an EC2 Auto Scaling Group, with zero manual intervention at any stage.

## Architecture Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   GitHub    │────▶│ GitHub      │────▶│   Jenkins   │────▶│ AWS         │
│   Repository│     │ Actions     │     │ (optional)  │     │ CodePipeline│
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                      │
                                                                      ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ CloudWatch  │◀────│   ALB       │◀────│    ASG      │◀────│  CodeDeploy │
│ + SNS       │     │             │     │  (EC2)      │     │             │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

## Project Structure

```
aws-cicd-pipeline/
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # GitHub Actions workflow
├── terraform/
│   ├── main.tf                # Main Terraform configuration
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values
│   └── modules/
│       ├── vpc/               # VPC networking module
│       ├── alb/               # Application Load Balancer module
│       ├── asg/               # Auto Scaling Group module
│       └── cloudwatch/        # CloudWatch monitoring module
├── aws-codepipeline/
│   ├── pipeline-config.yaml   # CodePipeline configuration
│   ├── buildspec.yml          # CodeBuild specification
│   ├── appspec.yml            # CodeDeploy specification
│   └── scripts/               # CodeDeploy hooks
├── scripts/
│   ├── deploy.sh              # Deployment script
│   └── user-data.sh           # EC2 instance initialization
├── Jenkinsfile                # Jenkins pipeline definition
└── README.md                  # This file
```

## Prerequisites

- **AWS Account** with appropriate permissions
- **GitHub Repository** for source control
- **AWS CLI** configured with credentials
- **Terraform** >= 1.0.0
- **Docker** (for building images)
- **Node.js** >= 18 (for application)

## AWS Services Used

| Service | Purpose |
|---------|---------|
| VPC | Networking infrastructure |
| EC2 | Compute instances |
| Auto Scaling Group | Auto scaling infrastructure |
| Application Load Balancer | Load balancing |
| ECR | Docker image registry |
| CodeBuild | Build service |
| CodeDeploy | Deployment service |
| CodePipeline | Pipeline orchestration |
| CloudWatch | Monitoring & logging |
| SNS | Notifications |
| IAM | Access management |

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/aws-cicd-pipeline.git
cd aws-cicd-pipeline
```

### 2. Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region: us-east-1
# Enter output format: json
```

### 3. Create S3 Bucket for Terraform State

```bash
aws s3 mb s3://your-terraform-state-bucket --region us-east-1
```

### 4. Update Terraform Configuration

Edit `terraform/variables.tf` to customize:

```hcl
# Environment name
environment = "prod"

# AWS region
aws_region = "us-east-1"

# EC2 instance type
instance_type = "t3.medium"

# Auto Scaling Group settings
min_size = 2
max_size = 10
desired_capacity = 3
```

### 5. Initialize and Apply Terraform

```bash
cd terraform/environments/prod
terraform init
terraform plan
terraform apply
```

### 6. Configure GitHub Secrets

In your GitHub repository, go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key with appropriate permissions |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key |
| `AWS_ECR_REPOSITORY` | ECR repository URI |
| `TERRAFORM_STATE_BUCKET` | S3 bucket for Terraform state |
| `STAGING_URL` | Staging environment URL |
| `PROD_URL` | Production environment URL |
| `SLACK_WEBHOOK_URL` | Slack webhook for notifications |

### 7. Trigger the Pipeline

Push code to the `develop` or `main` branch to trigger the CI/CD pipeline:

```bash
git add .
git commit -m "Initial commit"
git push origin main
```

## Pipeline Flow

### GitHub Actions Workflow

1. **CI Stage**
   - Checkout code
   - Install dependencies
   - Run linter
   - Run tests with coverage
   - Build application

2. **Security Scan**
   - Trivy vulnerability scanning
   - Upload results to GitHub Security

3. **Build & Push Docker**
   - Build Docker image
   - Push to Amazon ECR

4. **Terraform Validation**
   - Initialize Terraform
   - Validate configuration
   - Create execution plan

5. **Deploy**
   - **Develop branch** → Staging environment
   - **Main branch** → Production environment (with approval)

### CodePipeline Flow

1. **Source** - GitHub (triggered on code changes)
2. **Build** - CodeBuild (builds Docker image)
3. **Deploy Staging** - CodeDeploy (deploys to staging)
4. **Approval** - Manual approval (production only)
5. **Deploy Production** - CodeDeploy (Blue/Green deployment)

## Monitoring & Alerts

### CloudWatch Alarms

| Alarm | Threshold | Action |
|-------|-----------|--------|
| CPU High | > 80% | SNS notification |
| Memory High | > 80% | SNS notification |
| ALB Response Time | > 1s | SNS notification |
| ALB 5xx Errors | > 0 | SNS notification |
| Instance Terminations | > 0 | SNS notification |

### SNS Notifications

Configure email subscriptions in `terraform/main.tf`:

```hcl
variable "notification_emails" {
  default = ["team@example.com"]
}
```

## Deployment Scripts

### Manual Deployment

```bash
# Deploy to EC2 instances
./scripts/deploy.sh v1.0.0

# View deployment logs
./scripts/deploy.sh --help
```

### EC2 User Data

The `user-data.sh` script automatically:
- Installs Docker and AWS CLI
- Configures CloudWatch logging
- Pulls the latest Docker image
- Starts the application

## Security Considerations

1. **IAM Roles** - Use instance profiles instead of access keys
2. **Security Groups** - Restrict access to necessary ports only
3. **Secrets Management** - Use AWS Secrets Manager for sensitive data
4. **Encryption** - Enable encryption at rest for all resources
5. **VPC** - Deploy in private subnets with NAT gateway

## Troubleshooting

### Check ASG Instances

```bash
aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names prod-asg \
    --query 'AutoScalingGroups[0].Instances'
```

### Check ALB Target Health

```bash
aws elbv2 describe-target-health \
    --target-group-arn <target-group-arn>
```

### View CloudWatch Logs

```bash
aws logs tail /aws/ec2/prod --follow
```

### Check CodeDeploy Status

```bash
aws deploy list-deployments \
    --application-name my-app \
    --deployment-group-name production
```

## Cleanup

```bash
# Destroy Terraform resources
cd terraform/environments/prod
terraform destroy

# Delete S3 bucket (optional)
aws s3 rb s3://your-terraform-state-bucket --force
```

## License

MIT License - See LICENSE file for details