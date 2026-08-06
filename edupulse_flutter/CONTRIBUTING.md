# Contributing Guidelines

Thank you for contributing to EduPulse AI. Please follow these guidelines to keep code quality and project health high.

## Branching & Workflow

- Always branch off of the `dev` or `master` branch.
- Name your branch according to: `feature/feature-name`, `bugfix/issue-name`, or `refactor/area-name`.
- Squash-merge pull requests with descriptive descriptions.

## Code Standards

- **Melos**: Use `melos run analyze` to check static analysis before opening a pull request.
- **Formatting**: Format all Dart code via `melos run format` (which invokes `dart format .` on all workspace packages).
- **Linter**: Strict rules are defined in the workspace root `analysis_options.yaml`. Do not ignore warnings unless absolutely necessary and documented.
- **Testing**: Ensure existing tests pass by running `melos run test`. Write unit/widget tests for new features.
- **Clean Architecture**: Follow the Presentation, Domain, and Data layer boundaries. Never import presentation UI libraries into the Domain layer.

## Monorepo Commands

Remember to run Melos commands inside the monorepo root:
- Bootstrap: `melos bootstrap`
- Format: `melos run format`
- Analyze: `melos run analyze`
- Tests: `melos run test`
