# Security Policy

We take security seriously and appreciate contributions that help keep the system and its users safe.

## Reporting a Vulnerability
- Please report suspected vulnerabilities privately via email: security@example.com
- Provide detailed steps to reproduce, potential impact, and any PoC if available.
- Do not submit vulnerability details in public issues or pull requests.

We will acknowledge receipt within 2 business days and aim to provide a timeline for remediation after triage.

## Hardening Guidelines
- No hardcoded secrets. Use environment variables and a secret manager (e.g., AWS Secrets Manager or SSM Parameter Store).
- Use least-privilege IAM roles for infrastructure and CI.
- Enforce HTTPS/TLS in transit; encrypt sensitive data at rest (KMS-managed keys).
- Validate all inputs; prefer allowlists over denylists.
- Log security-relevant events (authz failures, policy violations) with structured logs.
- Keep dependencies updated; monitor CVEs and apply patches promptly.

## Security Scanning
- CodeQL scanning is configured in .github/workflows/codeql.yml.
- Consider adding additional scanners (e.g., dependency audit, IaC scanning, secret scanning) in subsequent steps.
