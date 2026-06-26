## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, invoke the `skill` tool with `skill: "graphify"` before doing anything else.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

## skill routing

This project has a local `.agents/skills/` directory with Flutter-specific and design skills. Use them as follows:

### When to use which skill

| User asks about | Use this skill | Why |
|---|---|---|
| Animations, motion, transitions | `flutter-animations` | Deep-dive into implicit/explicit animations, Hero, physics, staggered |
| Project structure, MVVM, Repository pattern, layering | `flutter-apply-architecture-best-practices` | Enforces strict separation of concerns (UI / Logic / Data) |
| Responsive layout, adaptive breakpoints, foldables | `flutter-build-responsive-layout` | LayoutBuilder-first approach, orientation guidance |
| Building UI components, screens, themes, general UX | `flutter-ui-ux` | End-to-end workflow: analyze → design → implement → optimize |
| Design system, color palette, typography, UX review | `ui-ux-pro-max` | Cross-platform design intelligence; always adapt output to Flutter |
| **Navigation & declarative routing** | `flutter-setup-declarative-routing` | GoRouter / declarative routing setup and best practices |
| **HTTP / API integration** | `flutter-use-http-package` | Using `http` package for backend communication |
| **JSON serialization** | `flutter-implement-json-serialization` | Model serialization/deserialization patterns |
| **Widget testing** | `flutter-add-widget-test` | Adding and writing Flutter widget tests |
| **Unit testing (Dart/Logic)** | `dart-add-unit-test` | Adding unit tests for business logic and data layers |
| **Error tracking / Crash reporting** | `sentry-flutter-sdk` | Sentry integration for production error monitoring |
| Finding or installing new skills | `find-skills` | Gateway to the external skills ecosystem via `npx skills` |

### Combining skills (recommended order)

1. **Start with `ui-ux-pro-max`** for design decisions (style, color, typography).
2. **Use `flutter-apply-architecture-best-practices`** to decide project structure and data flow.
3. **Use `flutter-ui-ux`** or `flutter-build-responsive-layout` to build the widgets.
4. **Use `flutter-animations`** when motion is required.
5. **Use `flutter-setup-declarative-routing`** for navigation and routing.
6. **Use `flutter-use-http-package`** + **`flutter-implement-json-serialization`** for API integration and data models.
7. **Use `flutter-add-widget-test`** + **`dart-add-unit-test`** for testing.
8. **Use `sentry-flutter-sdk`** for production error tracking.
9. **Run `graphify update .`** after code changes to keep the knowledge graph current.

### Missing skills (not yet available in ecosystem)

The following areas are critical but do not yet have installable skills meeting the quality threshold (1K+ installs, official source):

| Area | Gap | Workaround |
|---|---|---|
| State Management (Riverpod / BLoC) | No official skill found | Use `flutter-apply-architecture-best-practices` + manual docs |
| Local Storage (Hive / Isar / SQLite) | No official skill found | Manual implementation |
| Forms & Validation | No Flutter-specific skill found | Use `flutter-ui-ux` + `ui-ux-pro-max` §8 |
| Dependency Injection (get_it / injectable) | No official skill found | Use `flutter-apply-architecture-best-practices` Step 7 |
| Security (secure storage, certificate pinning) | No official skill found | Manual implementation |
| CI/CD (Fastlane / Codemagic) | Install count <100 | Evaluate `rodydavis/skills@using-fastlane-in-flutter-and-ci` with caution |

### Stack clarification

This is a **Flutter** project. When using `ui-ux-pro-max`, its examples may reference React Native or web patterns; always translate those recommendations to Flutter equivalents (e.g., `GestureDetector` instead of `Pressable`, `MaterialApp` routing instead of React Navigation).
