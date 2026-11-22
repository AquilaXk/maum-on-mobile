# Third-Party Open-Source Notices

Maum On Mobile relies on the permissive open-source runtime dependencies listed below.

---

## 1. First-Party Clean-Room Implementations

The following components in this repository are first-party clean-room implementations without third-party UI or algorithm wrapper dependencies:

- UI surface, card, badge, and theme primitives (`front/lib/shared/ui/shad_primitives.dart`, `front/lib/theme/app_theme.dart`)
- Bounded single-pass Markdown parser and Flutter renderer (`front/lib/shared/markdown/clean_markdown_body.dart`, `front/lib/features/consultation/presentation/widgets/counselor_markdown_message.dart`)
- Staggered typing dots and breathing/sensory grounding widgets (`front/lib/features/consultation/presentation/widgets/jumping_dots_indicator.dart`, `front/lib/features/consultation/presentation/widgets/breathing_grounding_sheet.dart`)
- Bit-packed annual mood calendar bitmap and single-canvas heatmap painter (`front/lib/features/diary/domain/mood_year_bitmap.dart`, `front/lib/features/diary/presentation/mood_heatmap_strip.dart`)
- Bit-parallel Hangul Choseong search and server-side multi-pattern text moderation engines (`front/lib/shared/algorithm/bitap_hangul_search.dart`, `back/src/main/kotlin/com/maumonmobile/domain/moderation/ModerationTextEngine.kt`)

---

## 2. Core Runtime Dependencies

- **Flutter & Dart Client (`front/`)**: `flutter` (BSD-3-Clause), `app_links` (BSD-3-Clause), `dio` (MIT), `file_picker` (MIT), `flutter_secure_storage` (BSD-3-Clause), `url_launcher` (BSD-3-Clause).
- **Kotlin / Spring Boot Backend (`back/`)**: Spring Boot / Spring Framework / Spring Security (Apache-2.0), Flyway (Apache-2.0), PostgreSQL JDBC / H2 (BSD / MPL-2.0 or EPL-1.0), Jackson (Apache-2.0), Kotlin Standard Library (Apache-2.0).
