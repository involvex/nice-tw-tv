---
title: Contributing
nav_order: 4
---

# Contributing

Contributions are welcome! Please follow these guidelines when working on Nice TV.

## Branch Naming

Use descriptive branch names with one of these prefixes:

- `feature/<feature-name>` — New features
- `fix/<bug-description>` — Bug fixes
- `refactor/<refactor-description>` — Code refactoring
- `docs/<documentation-change>` — Documentation updates
- `chore/<maintenance-task>` — Maintenance tasks

Examples:
- `feature/category-browse-frontpage`
- `fix/chat-reconnect-loop`

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation
- `style:` for formatting
- `refactor:` for code refactoring
- `test:` for tests
- `chore:` for maintenance

Example:
```
feat: add CategoryBrowseScreen with card-based infinite scroll
```

## Pre-commit Checklist

Before committing, run:

```bash
dart format .
flutter analyze
flutter test
```

Verify `.env` is not staged and no secrets are committed.

## Code Standards

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `dart format .` before committing
- Run `flutter analyze` to check for issues
- Prefer `const` constructors where possible
- Use `final` for immutable variables
- Use `late` for late-initialized variables
- One class per file (recommended)
- Keep `data/` and `presentation/` separate

## Pull Requests

1. Push your branch to GitHub
2. Open a PR with a clear description of the change
3. Ensure all checks pass (lint, tests, build)
4. Request review from a maintainer

## Development Tips

- Use `flutter run` for debug mode with hot reload
- Use Flutter Inspector in your IDE for widget tree inspection
- Profile with `flutter run --profile` for performance issues
- Check for unnecessary rebuilds with Flutter Inspector
