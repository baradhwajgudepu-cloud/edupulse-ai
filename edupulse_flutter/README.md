# EduPulse AI Flutter Monorepo

Welcome to the **EduPulse AI** Flutter monorepo. This workspace contains the mobile and web client applications for the EduPulse AI platform, managed with [Melos](https://melos.invertase.dev/).

## Monorepo Layout

```text
edupulse_flutter/
  apps/
    parent_app/             - Mobile Client for Parents/Guardians (Active Development)
    teacher_app/            - Mobile Client for Teachers (Placeholder)
    principal_app/          - Mobile Client for School Principals (Placeholder)
    admin_portal/           - Admin Web Client (Placeholder)
  packages/
    edupulse_core/          - Reusable utility methods, logger, and error models
    edupulse_config/        - Environment configurations, flavors, and feature flags
    edupulse_assets/        - Shared media assets (icons, SVG files, logos, Lottie animations)
    edupulse_models/        - Domain and shared API model definitions (generated via Freezed)
    edupulse_network/       - Network engine layer (Dio client, JWT and refresh token interception)
    edupulse_api/           - REST API endpoints, DTO mappers, and repository boundaries
    edupulse_auth/          - Session, caching, and account authentication workflows
    edupulse_theme/         - Central design theme and Material 3 palettes
    edupulse_localization/  - Multi-language localization and translation configs
    edupulse_ui/            - Reusable UI component library (buttons, inputs, charts, calendars)
```

## Getting Started

### Prerequisites
- Flutter SDK (Stable 3.x)
- Dart SDK

### Installation

1. Install Melos globally if you haven't already:
   ```bash
   dart pub global activate melos
   ```

2. Bootstrap the workspace (this runs `pub get` on all sub-packages and links them together):
   ```bash
   melos bootstrap
   ```

## Development Commands

Melos provides commands to manage tasks across the entire monorepo:

- **Format Code**:
  ```bash
  melos run format
  ```
- **Analyze Workspace**:
  ```bash
  melos run analyze
  ```
- **Run All Tests**:
  ```bash
  melos run test
  ```
- **Clean Workspace**:
  ```bash
  melos clean
  ```
