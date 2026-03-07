# AGENTS.md

Guidance for coding agents working in this repository.

## Repo Status

- Current repository is in a planning stage.
- At time of writing, only `README.md` and `DEVELOPMENT-PLAN.md` exist.
- No `lib/`, `test/`, `pubspec.yaml`, or CI config was found yet.
- Treat this file as operating guidance for upcoming Flutter/Dart implementation.

## Rules Files Check

- `.cursor/rules/`: not found.
- `.cursorrules`: not found.
- `.github/copilot-instructions.md`: not found.
- If any of these files are added later, they become higher-priority constraints.

## Project Intent (from docs)

- App: JITA (Just In Time App), built with Flutter.
- Domain: traffic-aware departure recalculation for one active route.
- External APIs: Google Routes API (`computeRouteMatrix`) and Places API.
- Suggested architecture: data/domain/background/notifications/ui split.

## Build, Lint, and Test Commands

Run these from repository root after Flutter project scaffold exists.

### Environment and setup

- `flutter --version` - verify Flutter SDK availability.
- `dart --version` - verify Dart SDK availability.
- `flutter pub get` - install dependencies.
- `flutter doctor -v` - validate local toolchain and platforms.

### Static analysis and formatting

- `dart format .` - auto-format all Dart files.
- `dart format lib test` - format primary source and tests only.
- `flutter analyze` - run analyzer and lints.
- `dart analyze` - analyzer alternative for Dart packages.

### Running the app

- `flutter run` - run in debug on selected device.
- `flutter run -d ios` - run on iOS simulator/device.
- `flutter run -d android` - run on Android emulator/device.
- `flutter run --dart-define=GOOGLE_MAPS_API_KEY=...` - inject secrets at runtime.

### Tests (all)

- `flutter test` - run all tests.
- `flutter test --coverage` - run all tests with coverage output.

### Tests (single test file)

- `flutter test test/domain/departure_calculator_test.dart`
- Preferred for file-focused iteration and faster feedback.

### Tests (single test case by name)

- `flutter test --plain-name "returns earlier departure when traffic increases" test/domain/departure_calculator_test.dart`
- Use `--plain-name` to target one test or one group in a file.

### Tests (name filter across files)

- `flutter test --plain-name "DepartureCalculator"`
- Useful when matching names across multiple test files.

### Integration / widget test patterns

- `flutter test test/ui/home/home_screen_test.dart` - widget test file.
- `flutter test integration_test` - integration test suite directory.

### Build artifacts

- `flutter build apk --release`
- `flutter build ios --release`
- `flutter build appbundle --release`

## Recommended Agent Workflow

- Read `README.md` and `DEVELOPMENT-PLAN.md` before edits.
- Prefer small, incremental patches that preserve planned architecture.
- Run `dart format` and `flutter analyze` before finalizing edits.
- Run targeted tests for changed modules, then broader suite when feasible.
- Do not commit secrets, API keys, generated credentials, or local env files.

## Code Style Guidelines (Dart/Flutter)

### Language level and lints

- Use latest stable Flutter/Dart compatible with project constraints.
- Enable and respect `flutter_lints` (or stricter custom lint profile).
- Treat analyzer warnings as issues to fix, not ignore.

### Formatting

- Use `dart format`; do not hand-format inconsistently.
- Keep lines readable; rely on formatter for wrapping.
- Use trailing commas in multi-line widget constructors and collections.
- Avoid unnecessary vertical whitespace and alignment formatting.

### Imports

- Order imports in groups:
  1) `dart:`
  2) `package:`
  3) relative project imports
- Keep one blank line between groups.
- Remove unused imports promptly.
- Prefer package imports for cross-feature references.

### Types and null safety

- Use sound null safety everywhere.
- Prefer explicit types on public APIs and non-obvious locals.
- Avoid `dynamic` unless absolutely required by external APIs.
- Narrow nullable types quickly with guards and early returns.
- Prefer immutable models with `final` fields.

### Naming conventions

- Classes/enums/extensions/types: `UpperCamelCase`.
- Variables/functions/methods/params: `lowerCamelCase`.
- File names: `snake_case.dart`.
- Constants: `lowerCamelCase` for Dart `const` by convention.
- Test descriptions should be behavior-focused and readable.

### Immutability and state

- Prefer `const` constructors/widgets where possible.
- Prefer `final` locals; use `var` only when type is obvious.
- Keep mutable state scoped to controllers/notifiers.
- In UI, keep widgets as stateless as possible.

### Error handling

- Fail fast on invalid input with clear exceptions/messages.
- Catch only errors you can handle meaningfully.
- Do not swallow exceptions silently.
- Map infrastructure errors into domain-meaningful failures.
- Include actionable context in logs (operation, route, timestamp).

### Async and concurrency

- Use `async`/`await` over nested callbacks.
- Wrap network calls with timeouts and explicit error handling.
- Do not block UI thread with heavy sync work.
- Ensure timers/background loops are cancellable and disposed safely.

### Architecture and layering

- Keep domain logic framework-agnostic (`domain/`).
- Keep API and persistence concerns in `data/`.
- Keep UI concerns in `ui/` with Riverpod controllers/providers.
- Keep background orchestration in `background/`.
- Keep notifications isolated in `notifications/`.
- Avoid leaking API DTO details into UI layer.

### API and secrets handling

- Never hardcode API keys in source.
- Use `--dart-define` or secure platform configuration.
- Validate required env/config at startup with clear errors.
- Use least-privilege field masks and request payloads.

### Testing conventions

- Co-locate tests by feature/domain under `test/` mirroring `lib/`.
- Unit test pure logic first (for example `DepartureCalculator`).
- Widget tests for form validation and state rendering.
- Integration tests for end-to-end polling + notification flows.
- Keep tests deterministic; mock network and clock dependencies.
- Prefer one behavioral assertion theme per test.

### Documentation and comments

- Write comments only for non-obvious intent or constraints.
- Keep public APIs documented when behavior is subtle.
- Update docs when architecture or commands change.

## PR and Change Hygiene for Agents

- Make focused changes; avoid incidental refactors.
- Preserve existing naming and folder conventions.
- Include or update tests with logic changes.
- Run formatter and analyzer before handing off.
- Always use Conventional Commits style for commit messages (for example: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`).
- In change notes, explain why the change is needed.

## If Repository Structure Changes

- Re-scan for `.cursor/rules/`, `.cursorrules`, and `.github/copilot-instructions.md`.
- Merge any discovered rules into this file and follow precedence.
- Update command examples to match actual scripts/tooling in `pubspec.yaml` or CI.
