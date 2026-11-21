# Security Policy

## Supported Versions

Security updates are applied to the latest state on the `main` branch.

| Version | Supported |
| :--- | :--- |
| `main` (latest) | Yes |

## Security Architecture & Invariants

Maum On Mobile enforces **Fail-Closed** security invariants across both the Kotlin/Spring Boot API backend and Flutter mobile client:

1. **Identity & Token Validation**:
   - External OIDC login exchanges verify provider signatures, issuers, audiences, and redirect targets before issuing local sessions.
   - Rate limiting enforces per-client budgets without trusting spoofed forwarded headers outside trusted proxy boundaries.
2. **Resource Ownership & Idempotency**:
   - Diaries, letters, reports, notifications, and consultation streams verify authenticated principal ownership on read and write paths.
   - State-changing write endpoints enforce atomic idempotency tracking to prevent replay or race-condition duplicates.
3. **Bounded Input & Stream Safety**:
   - Content moderation classifiers enforce strict payload length bounds (`<= 20,000` characters) and remote circuit-breaker timeouts.
   - Server-Sent Events (SSE) clients and backend emitters isolate sessions per connection generation and bound line/event buffer sizes.
4. **Zero Silent Fallbacks**:
   - Expired sessions, malformed OAuth state, moderation timeouts, or persistence failures surface explicit errors without fabricating success responses.

## Reporting a Vulnerability

Please report suspected vulnerabilities privately via [GitHub Security Advisories](https://github.com/AquilaXk/maum-on-mobile/security/advisories/new) rather than opening a public issue.
