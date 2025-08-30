# Infrastructure

Use this directory for Infrastructure-as-Code with Terraform.

Layout:
- terraform/modules/ (reusable)
  - lambda/ (Lambda packaging + role)
  - api_gateway/ (HTTP API + integrations)
  - dynamodb/ (PAY_PER_REQUEST with TTL)
- terraform/envs/demo/
  - main.tf

Security:
- Use least-privilege IAM roles.
- Store remote state in a secure backend (e.g., S3 + DynamoDB lock) with encryption.
- Never commit secrets or state files.

Notes:
- Region: us-east-1
- Single environment: demo only (production-ready notes kept in docs)
- Compute: Lambda (container-ready), API Gateway HTTP API
- Data: DynamoDB (on-demand), SQS/SNS to be added later
- Secrets: SSM Parameter Store (standard tier)
- No VPC by default to avoid NAT costs

Getting started:
1. Install Terraform >= 1.6 and AWS CLI; configure AWS credentials
2. cd infrastructure/terraform/envs/demo
3. terraform init
4. terraform apply -var="project_name=rtp"
