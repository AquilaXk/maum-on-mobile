# Third-Party Open-Source Notices

Maum On Mobile relies on the permissive open-source runtime dependencies listed below.

---

## 1. First-Party Clean-Room Implementations

The following components in this repository are first-party clean-room implementations without third-party UI, network, storage, OS bridge, or algorithm wrapper dependencies:

- UI surface, card, badge, and theme primitives (`front/lib/shared/ui/shad_primitives.dart`, `front/lib/theme/app_theme.dart`)
- Bounded single-pass Markdown parser and Flutter renderer (`front/lib/shared/markdown/clean_markdown_body.dart`, `front/lib/features/consultation/presentation/widgets/counselor_markdown_message.dart`)
- Staggered typing dots and breathing/sensory grounding widgets (`front/lib/features/consultation/presentation/widgets/jumping_dots_indicator.dart`, `front/lib/features/consultation/presentation/widgets/breathing_grounding_sheet.dart`)
- Bit-packed annual mood calendar bitmap and single-canvas heatmap painter (`front/lib/features/diary/domain/mood_year_bitmap.dart`, `front/lib/features/diary/presentation/mood_heatmap_strip.dart`)
- Bit-parallel Hangul Choseong search and server-side multi-pattern text moderation engines (`front/lib/shared/algorithm/bitap_hangul_search.dart`, `back/src/main/kotlin/com/maumonmobile/domain/moderation/ModerationTextEngine.kt`)
- Conditional HTTP/SSE transport (`front/lib/core/network/http_api_transport.dart`, `front/lib/features/notification/data/notification_repository.dart`)
- Platform secure key-value storage (`front/lib/core/storage/secure_key_value_storage.dart`, `front/android/app/src/main/kotlin/com/aquilaxk/maumonmobile/SecureStorageChannel.kt`, iOS Keychain channel in `front/ios/Runner/AppDelegate.swift`)
- Allowlisted external URI launcher and OIDC deep-link bridge (`front/lib/core/platform/external_url_launcher.dart`, `front/lib/core/platform/deep_link_channel.dart`, native handlers in `MainActivity.kt`, `AppDelegate.swift`, and `SceneDelegate.swift`)
- JDK 21 RS256 service-account JWT assertion and OAuth2 token exchange client (`back/src/main/kotlin/com/maumonmobile/adapter/out/ai/VertexAiGenerateContentClient.kt`)

---

## 2. Core Runtime Dependencies

- **Flutter & Dart Client (`front/`)**: `flutter` (BSD-3-Clause).
- **Kotlin / Spring Boot Backend (`back/`)**: Spring Boot / Spring Framework / Spring Security (Apache-2.0), Flyway (Apache-2.0), PostgreSQL JDBC / H2 (BSD / MPL-2.0 or EPL-1.0), Jackson (Apache-2.0), Kotlin Standard Library (Apache-2.0).
