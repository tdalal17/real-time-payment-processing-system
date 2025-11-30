# Contributing

Thanks for your interest in contributing! This project prioritizes security, clarity, and testability.

## Development Workflow
- Fork the repo and create a feature branch from main.
- Write clear, small commits with conventional messages (e.g., feat:, fix:, docs:, chore:).
- Add tests for new behavior; keep coverage meaningful.
- Run linters and tests locally before opening a PR.

## Code Style
- Prefer clear, descriptive names over abbreviations.
- Handle errors explicitly; fail fast and log actionable context.
- Keep functions small and cohesive. Avoid deep nesting.
- Add docstrings/comments only where the intent is non-obvious.

## Security
- Never commit secrets. Use environment variables and secret managers.
- Avoid printing sensitive data in logs.
- Follow least-privilege when proposing infra or CI changes.

## Pull Requests
- Describe the problem, the approach, and any trade-offs.
- Include screenshots for user-facing changes when applicable.
- Link related issues and ADRs.

## Communication
- Use GitHub issues and PRs for discussion.
- Be respectful and constructive.
