# AGENTS.md

Repository guidance for coding agents working in `apxy-ios`.

## Project Summary

`apxy-ios` is an Apple-platform SDK for capturing `URLSession` traffic and sending it to APXY.

The repo contains two products:

- `ApxyCore`: capture, session lifecycle, buffering, transport, and local debug persistence
- `ApxyUI`: embedded SwiftUI console backed by `ApxyCore`

## Architecture

This project follows a Clean Architecture style with pragmatic folder boundaries.

### `Sources/ApxyCore/Public/`

Public API surface only.

- `API/`: top-level entry points such as `Apxy`
- `Configuration/`: public options and configuration types
- `Models/`: public data models exposed to SDK consumers

When a task changes what app developers import or call, start here first.

### `Sources/ApxyCore/Domain/`

Core domain models and debug/session data structures.

- Debug models
- Session models

This layer should stay framework-light and focused on data meaning, not UI or transport details.

### `Sources/ApxyCore/Application/`

Use-case and orchestration layer.

- `Capture/`: normalized payload creation and transfer-size shaping
- `Session/`: runtime coordination through `SessionManager`

This is where most behavioral changes land when the task affects SDK flow.

### `Sources/ApxyCore/Infrastructure/`

Adapters and side effects.

- `Interception/`: `ApxyURLProtocol`, swizzling, domain filtering
- `Transport/`: HTTP/WebSocket/session transport adapters
- `Debug/`: local debug store persistence
- `System/`: device/app/logger/connection helpers
- `Support/`: utility structures such as the record buffer

If the task touches networking mechanics, persistence, or platform integration, it usually ends here.

### `Sources/ApxyUI/Application/`

Presentation orchestration for the embedded console.

- console interactor
- view state
- derived state
- filter state

This layer transforms store snapshots into screen-ready state.

### `Sources/ApxyUI/UI/`

SwiftUI rendering only.

- `Console/`: list, filters, navigation, screen model, container
- `Detail/`: inspector screens and detail components
- `Shared/`: formatting, reusable presentation, preview fixtures, support helpers

If a task is visual, start here, but trace back into `ApxyUI/Application` before changing behavior.

## Runtime Flow

### Capture Flow

Use this path when debugging SDK behavior:

1. `Apxy.start(serverURL:options:)` in `Sources/ApxyCore/Public/API/Apxy.swift`
2. interception setup through swizzling and/or `ApxyURLProtocol`
3. request/response normalized into `CapturePayload`
4. `SessionManager.capture(...)` creates `NetworkRecord`
5. record is written to local `ApxyDebugStore` when debug console is enabled
6. record is dispatched through buffered HTTP or immediate WebSocket transport

### Debug UI Flow

Use this path when debugging console behavior:

1. `ApxyDebugConsoleContainer` or `ApxyDebugConsoleView`
2. `ApxyDebugConsoleScreenModel`
3. `ApxyDebugConsoleViewModel`
4. `ApxyDebugConsoleInteractor`
5. snapshots streamed from `ApxyDebugStore`
6. derived/filter state computed
7. SwiftUI views under `Sources/ApxyUI/UI/Console/` and `Sources/ApxyUI/UI/Detail/`

## How To Start A Task

Choose the narrowest entry point that matches the request.

### If the task is public API or SDK integration

Start with:

- `Sources/ApxyCore/Public/API/Apxy.swift`
- `Sources/ApxyCore/Public/Configuration/`
- `README.md`

Then trace inward to `Application` and `Infrastructure`.

### If the task is network capture or transport

Start with:

- `Sources/ApxyCore/Infrastructure/Interception/`
- `Sources/ApxyCore/Application/Capture/`
- `Sources/ApxyCore/Application/Session/SessionManager.swift`
- tests in `Tests/ApxyCoreTests/`

### If the task is embedded debug UI

Start with:

- `Sources/ApxyUI/UI/Console/Screens/`
- `Sources/ApxyUI/UI/Detail/Screens/`
- `Sources/ApxyUI/Application/Console/`
- tests in `Tests/ApxyUITests/`

### If the task is previews

Start with:

- `Sources/ApxyUI/UI/Shared/Preview/`

Do not duplicate preview data inside every view when shared fixtures already cover the state.

## Working Rules

- Keep diffs small, direct, and reversible.
- Prefer changing existing layers over creating new abstractions.
- Do not add dependencies unless the task truly requires them.
- Keep public API changes intentional. Any change under `Sources/ApxyCore/Public/` is user-facing.
- Preserve separation between Public, Domain, Application, Infrastructure, and UI layers.
- If behavior changes, update tests close to that behavior.
- If public usage changes, update `README.md`.
- If configuration surface changes, update `docs/configuration.md`.
- If UI state changes, keep SwiftUI previews working for the main console and detail screens.

## Verification

Use the narrowest command that proves the change, then broaden only when needed.

- build package: `swift build`
- run all tests: `swift test`
- run one test target: `swift test --filter ApxyDebugConsoleTests`

For docs-only changes, verify paths, links, and command examples instead of running the full suite.

## Notes

- `CLAUDE.md` should mirror this file via symlink, not duplicate repo guidance.
- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.
