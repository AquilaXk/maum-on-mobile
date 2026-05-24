# maum-on-mobile

Mobile app repository for Maum On, focused on Android and iOS clients.

## Goal

- Build a dedicated mobile app for Android and iOS.
- Use the existing Maum On product behavior and API contracts as the source of truth.
- Keep mobile client work isolated from the existing web/backend repository.

## Workspace

- `front/`: Android/iOS mobile app client.
- `back/`: API server for the mobile app.
- `docker/`: local runtime containers and operational compose files.
- `infra/`: deployment and infrastructure assets.

## Initial Scope

- Choose the mobile stack.
- Map authentication, onboarding, and primary user flows from the existing Maum On project.
- Define backend API contracts needed by the mobile client.
- Set up CI, automated tests, and pull request review automation before feature work grows.

## Review Automation

CodeRabbit is configured through `.coderabbit.yaml` in this repository root. CodeRabbit reviews start on pull requests after the CodeRabbit GitHub App is installed for this repository.
