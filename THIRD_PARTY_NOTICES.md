# Third-Party Open-Source Notices

Maum On Mobile incorporates algorithms, UI interaction patterns, and open-source runtime dependencies under permissive licenses (MIT, Apache-2.0, BSD-3-Clause).

---

## 1. Referenced Algorithms & UI Patterns

The following permissive open-source projects served as architectural and algorithmic references (see also `README.md`):

| Reference Project | License | Role in Repository |
| :--- | :--- | :--- |
| [robert-bor/aho-corasick](https://github.com/robert-bor/aho-corasick) | Apache-2.0 | Multi-pattern Aho-Corasick automaton architecture (`ModerationTextEngine.kt`) |
| [hankcs/AhoCorasickDoubleArrayTrie](https://github.com/hankcs/AhoCorasickDoubleArrayTrie) | Apache-2.0 | Flat `IntArray` transition table layout (`ModerationTextEngine.kt`) |
| [krisk/Fuse](https://github.com/krisk/Fuse) | Apache-2.0 | 64-bit Myers / 31-bit Bitap bit-parallel fuzzy matching (`ModerationTextEngine.kt`, `bitap_hangul_search.dart`) |
| [toss/es-hangul](https://github.com/toss/es-hangul) | MIT | Arithmetic Hangul Jamo & Choseong decomposition (`ModerationTextEngine.kt`, `bitap_hangul_search.dart`) |
| [usememos/memos](https://github.com/usememos/memos) | MIT | Mood heatmap + quick-filter timeline layout (`diary_screen.dart`, `home_screen.dart`) |
| [devappmin/flutter_heatmap_calendar](https://github.com/devappmin/flutter_heatmap_calendar) | MIT | Calendar grid alignment (`mood_year_bitmap.dart`, `mood_heatmap_strip.dart`) |
| [hashirshoaeb/star_book](https://github.com/hashirshoaeb/star_book) | MIT | 5-level mood color mapping & daily mood check-in hero card reference (`mood_year_bitmap.dart`, `home_screen.dart`) |
| [contribution_heatmap](https://pub.dev/packages/contribution_heatmap) | BSD-3-Clause | Single `CustomPainter` canvas heatmap rendering (`mood_heatmap_strip.dart`) |
| [flyerhq/flutter_chat_ui](https://github.com/flyerhq/flutter_chat_ui) & [flutter/ai](https://github.com/flutter/ai) | Apache-2.0 / BSD-3-Clause | Grouped chat bubbles & streaming chat bubble isolation via `ValueListenableBuilder` (`consultation_screen.dart`, `consultation_controller.dart`) |
| [nank1ro/flutter-shadcn-ui](https://github.com/nank1ro/flutter-shadcn-ui) | MIT | `shadcn_ui` 0.59.0 (`ShadTheme`, `ShadCard`, `ShadBadge`) surface contrast and navigation elevation tokens (`app_theme.dart`, `app_design_system.dart`, `maum_bottom_navigation.dart`) |

---

## 2. Core Runtime Dependencies

- **Flutter & Dart Client (`front/`)**: `flutter` (BSD-3-Clause), `dio` (MIT), `app_links` (BSD-3-Clause), `file_picker` (MIT), `flutter_secure_storage` (BSD-3-Clause), `shadcn_ui` 0.59.0 (MIT), `url_launcher` (BSD-3-Clause).
- **Kotlin / Spring Boot Backend (`back/`)**: Spring Boot / Spring Framework / Spring Security (Apache-2.0), Flyway (Apache-2.0), PostgreSQL JDBC / H2 (BSD / MPL-2.0 or EPL-1.0), Jackson (Apache-2.0), Kotlin Standard Library (Apache-2.0).
