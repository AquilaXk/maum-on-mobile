# maum-on-mobile

Mobile app repository for Maum On, focused on Android and iOS clients.

## Goal

- Build a dedicated mobile app for Android and iOS.
- Use the existing Maum On product behavior and API contracts as the source of truth.
- Keep mobile client work isolated from the existing web/backend repository.

## Workspace

- `front/`: Flutter mobile app client for Android and iOS.
- `back/`: Kotlin/Spring Boot API server for the mobile app.
- `docker/`: local runtime containers and operational compose files.
- `infra/`: deployment and infrastructure assets.

## Frontend Commands

Run Flutter commands from `front/`:

- `flutter pub get`: install Flutter dependencies.
- `flutter analyze`: run static analysis.
- `flutter test`: run simulator-free widget and unit tests.
- `flutter run -d android`: run the app on an Android emulator or device.
- `flutter run -d ios`: run the app on an iOS simulator or device.
- `flutter build apk --debug`: build the Android debug app without release signing.
- `flutter build ios --simulator --no-codesign`: build the iOS simulator app without code signing.

Run repository contract tests from the repository root:

- `node --test tools/ci/*.test.mjs`: run repository and Flutter scaffold contract tests.

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
