# EduPulse AI Client Architecture

This document details the architectural boundaries and software engineering guidelines for the **EduPulse AI** client application suite.

---

## Architectural Philosophy

We follow **Strict Clean Architecture** combined with a **Feature-First** structure. The main goals are modularity, testability, and maintainability.

```
       +-----------------------------------------------------------+
       |                     Presentation Layer                     |
       |  (UI Widgets, Pages, Riverpod Providers, Controllers)     |
       +-----------------------------+-----------------------------+
                                     |
                                     v (Uses Use Cases & Entities)
       +-----------------------------------------------------------+
       |                        Domain Layer                       |
       |   (Usecases, Entities, Repository Interfaces - PURE DART) |
       +-----------------------------+-----------------------------+
                                     ^
                                     | (Implements Repository Interface)
       +-----------------------------+-----------------------------+
       |                         Data Layer                        |
       |  (Repo Implementations, Datasources, DTOs, API Mappers)   |
       +-----------------------------------------------------------+
```

### 1. Presentation Layer
- Contains Flutter UI layouts, reusable widgets, navigation flow, and Riverpod providers.
- **Rules**:
  - Zero raw business logic inside UI Widgets.
  - Presentation must *never* reference network packages (e.g. `Dio`), raw database components, or network DTO schemas directly.
  - Rebuilds must be optimized using `const` constructors.

### 2. Domain Layer
- Contains Use Cases, Entities, and Repository Interfaces.
- Written in **pure Dart**.
- **Rules**:
  - **No Flutter imports**. It must be plain Dart code.
  - Represents the core business logic of the app.
  - Independent of databases, APIs, or UI frameworks.

### 3. Data Layer
- Contains Repository Implementations, Remote/Local Data Sources, API Mappers (which map API DTOs to Domain Entities), and Model classes.
- **Rules**:
  - Translates data between the network layer/databases and the Domain layer.
  - Implements the Repository interfaces defined in the Domain layer.

---

## Package Boundary Map

To support code reuse across multiple apps (Parent, Teacher, Principal, Admin), the client codebase is split into the following packages:

```mermaid
graph TD
  parent_app[parent_app] --> edupulse_core
  parent_app --> edupulse_config
  parent_app --> edupulse_assets
  parent_app --> edupulse_models
  parent_app --> edupulse_network
  parent_app --> edupulse_api
  parent_app --> edupulse_auth
  parent_app --> edupulse_theme
  parent_app --> edupulse_localization
  parent_app --> edupulse_ui

  edupulse_ui --> edupulse_core
  edupulse_ui --> edupulse_theme
  edupulse_ui --> edupulse_localization
  edupulse_ui --> edupulse_assets

  edupulse_auth --> edupulse_core
  edupulse_auth --> edupulse_network
  edupulse_auth --> edupulse_api
  edupulse_auth --> edupulse_models

  edupulse_api --> edupulse_core
  edupulse_api --> edupulse_network
  edupulse_api --> edupulse_models

  edupulse_network --> edupulse_core
  edupulse_network --> edupulse_config

  edupulse_models --> edupulse_core

  edupulse_theme --> edupulse_core
  edupulse_localization --> edupulse_core
  edupulse_config --> edupulse_core
```

---

## State Management Rules

- **Riverpod** is the ONLY permitted state management framework.
- Always use `Notifier` or `AsyncNotifier` (or their autoDispose versions) for state management.
- **NEVER** use:
  - `setState` for business logic (only local UI state like toggles or controllers).
  - Bloc, Cubit, GetX, MobX, or vanilla ChangeNotifier.
- Leverage `AsyncValue` to handle asynchronous actions, exposing loading, success, and error states cleanly.
