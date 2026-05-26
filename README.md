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

Run Flutter commands through the repository wrapper:

- `tools/flutterw --version`: verify the Flutter SDK found by the repository wrapper.
- `tools/ci/run-local-mobile-checks.sh`: install Flutter dependencies, analyze the app, and run tests from `front/`.
- `tools/ci/run-local-mobile-checks.sh --doctor`: check local Flutter, Android SDK, Xcode, and CocoaPods state.
- `tools/flutterw run -d android`: run the app on an Android emulator or device.
- `tools/flutterw run -d ios`: run the app on an iOS simulator or device.
- `tools/flutterw build apk --debug`: build the Android debug app without release signing.
- `tools/flutterw build ios --simulator --no-codesign`: build the iOS simulator app without code signing.
- `tools/ci/run-mobile-release-preflight.sh --platform android`: check Android release build tooling.
- `tools/ci/run-mobile-release-preflight.sh --platform ios`: check iOS release build tooling.
- `tools/ci/run-mobile-release-preflight.sh --platform all`: check Android and iOS release build tooling.

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
