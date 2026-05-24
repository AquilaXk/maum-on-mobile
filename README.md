# maum-on-mobile

Mobile app repository for Maum On, focused on Android and iOS clients.

## Goal

- Build a dedicated mobile app for Android and iOS.
- Use the existing Maum On product behavior and API contracts as the source of truth.
- Keep mobile client work isolated from the existing web/backend repository.

## Workspace

- `front/`: Expo/React Native TypeScript mobile app client for Android and iOS.
- `back/`: Kotlin/Spring Boot API server for the mobile app.
- `docker/`: local runtime containers and operational compose files.
- `infra/`: deployment and infrastructure assets.

## Frontend Commands

Run commands from `front/`:

- `npm run lint`: validate the mobile project contract.
- `npm test`: run simulator-free contract tests.
- `npm run build`: run TypeScript checks and build contract validation.

## Backend Architecture

The backend follows hexagonal architecture package boundaries:

- `domain`: domain models and business rules.
- `application`: use cases, input ports, and application services.
- `adapter`: external input/output adapters such as web controllers.
- `global`: shared configuration and cross-cutting infrastructure.

## Initial Scope

- Choose the mobile stack.
- Map authentication, onboarding, and primary user flows from the existing Maum On project.
- Define backend API contracts needed by the mobile client.
- Set up CI, automated tests, and pull request review automation before feature work grows.

## Review Automation

CodeRabbit is configured through `.coderabbit.yaml` in this repository root. CodeRabbit reviews start on pull requests after the CodeRabbit GitHub App is installed for this repository.
