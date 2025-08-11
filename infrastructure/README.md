# Infrastructure

Use this directory for Infrastructure-as-Code (Terraform or CloudFormation).

Recommended layout (Terraform example):
- modules/
- envs/ (e.g., dev, staging, prod)
- providers.tf
- main.tf
- variables.tf
- outputs.tf

Security:
- Use least-privilege IAM roles.
- Store remote state in a secure backend (e.g., S3 + DynamoDB lock) with encryption.
- Never commit secrets or state files.
