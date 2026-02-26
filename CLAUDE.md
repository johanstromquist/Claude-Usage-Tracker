# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Usage Tracker is a native macOS menu bar app (Swift/SwiftUI) that monitors Claude AI usage limits in real time. It supports multiple profiles with isolated credentials and settings, 5-hour session windows, weekly usage tracking, and Opus-specific consumption. Privacy-first with zero telemetry -- all data stored locally.

**Platform**: macOS 14.0+ (Sonoma)
**Xcode**: 16+ required (uses `PBXFileSystemSynchronizedRootGroup`)
**Swift**: 5.0+

## Build & Test Commands

```bash
# Build debug
xcodebuild build \
  -project "Claude Usage.xcodeproj" \
  -scheme "Claude Usage" \
  -configuration Debug \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Run tests
xcodebuild test \
  -project "Claude Usage.xcodeproj" \
  -scheme "Claude Usage" \
  -configuration Debug \
  -derivedDataPath build \
  -destination "platform=macOS" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Build release
xcodebuild build \
  -project "Claude Usage.xcodeproj" \
  -scheme "Claude Usage" \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

No code signing is needed for local development or CI. The code signing bypass flags are required.

## Architecture

**Pattern**: MVVM with protocol-oriented design, async/await networking, Combine for reactive updates.

### Key Layers

- **App/** -- Entry point (`ClaudeUsageTrackerApp.swift`) and lifecycle (`AppDelegate.swift` handles setup wizard, notifications)
- **MenuBar/** -- Status bar management: `MenuBarManager` owns the NSStatusItem, `StatusBarUIManager` handles multi-profile icon rendering, `UsageRefreshCoordinator` orchestrates per-profile refresh intervals
- **Views/** -- SwiftUI views. `SettingsView` is the main settings window with sidebar navigation. Settings are split into `Credentials/`, `Profile/`, `App/` subdirectories
- **Shared/Services/** -- Core business logic:
  - `ClaudeAPIService` -- Fetches usage from Claude.ai web API and API console. Split across `+Types.swift` and `+ConsoleAPI.swift` extensions
  - `ClaudeCodeSyncService` -- Syncs CLI OAuth credentials
  - `ProfileManager` / `ProfileStore` -- Profile CRUD and persistence
  - `KeychainService` -- Secure credential storage (migrated from UserDefaults in v2.0)
  - `StatuslineService` -- Claude Code terminal integration
- **Shared/Models/** -- Data types: `Profile` (complete isolated profile), `ClaudeUsage`, `APIUsage`, `MenuBarIconConfig`, `ProfileDisplayMode` (Single/Multi enum)
- **Shared/Protocols/** -- `APIServiceProtocol`, `StorageProvider` for testability

### Credential Storage Hierarchy

Sensitive data lives in macOS Keychain (not UserDefaults). When fetching usage, the fallback order is:
1. Profile's Claude.ai session key
2. Profile's saved CLI OAuth token
3. System Keychain CLI token

### Multi-Profile Menu Bar (v2.3.0)

Profiles have `isSelectedForDisplay` to control which appear in the menu bar. `MultiProfileDisplayConfig` controls ordering, spacing, and max visible profiles. Single vs Multi mode is toggled via `ProfileDisplayMode`.

## API Endpoints

- **Web usage**: `GET https://claude.ai/api/organizations/{org_id}/usage` (Cookie auth with session key)
- **API console**: `GET https://api.anthropic.com/v1/organization/{org_id}/usage` (x-api-key header)
- **Status**: `GET https://status.claude.com/api/v2/status.json`

## Conventions

- **Conventional Commits**: `feat(scope):`, `fix(scope):`, `docs(scope):`, etc.
- **Branch naming**: `feat/`, `fix/`, `docs/`, `refactor/`, `chore/` prefixes
- **Code organization**: Use `// MARK: -` comments to separate Properties, Initialization, Public Methods, Private Methods
- **Localization**: 8 languages in `Shared/Localization/`. Use `NSLocalizedString` for user-facing strings.
- **Entitlements**: Debug uses `ClaudeUsageTracker.entitlements`, Release uses `Claude UsageRelease.entitlements`

## Release Process

1. Bump `MARKETING_VERSION` in `project.pbxproj`
2. Update `CHANGELOG.md`
3. Commit, tag with `vX.Y.Z`, push with tags
4. GitHub Actions creates a draft release with the `.app` zip and SHA256 checksum
