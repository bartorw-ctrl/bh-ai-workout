# BH AI Workout

Personal iOS workout tracker. **`SPEC.md` is the source of truth** — read it before any work and check changes against its numbered requirements.

## Stack
- Swift 5.10+/SwiftUI, iOS 17+, iPhone only.
- SwiftData for storage, Swift Charts, HealthKit, UserNotifications. No third-party packages.
- Project generated with XcodeGen (`project.yml`); don't hand-edit `.xcodeproj`.

## Layout
- `App/` — SwiftUI app target (views, HealthKit, notifications).
- `Core/` — local Swift package with pure logic (set-tap rules, weight rules, unit conversion, CSV/JSON export/import, progress aggregation). No UIKit/SwiftUI imports, so it is unit-testable with `swift test`.

## Verify every change
1. `cd Core && swift test`
2. `xcodegen generate && xcodebuild -scheme BHAIWorkout -destination 'platform=iOS Simulator,name=iPhone 17' build`
Fix all errors and warnings before reporting done.

## Owner
Single user, runs on their own iPhone via a free personal-team signing. Explain Xcode steps in plain language — the owner is not a developer.
