# My Business Idea iOS

Separate iPhone/iPad app built from scratch in SwiftUI, reusing the existing backend and product flow from the Android app.

## Scope

This project mirrors the Android product without changing the Android codebase:

- Authentication
- Password recovery
- Home discovery flow
- My Ideas + local drafts
- Favorites
- Idea details
- Related YouTube videos
- Text export
- PDF export (premium)
- Local notification idea packs
- Review prompt
- StoreKit premium subscriptions
- AdMob wrappers with safe fallbacks
- Firebase analytics/crashlytics bootstrap

## Current repo status

This repo is intentionally generated in a way that works from Windows and is finished on a Mac:

- Source code is complete in Swift
- Project generation uses `XcodeGen`
- The real `.xcodeproj` must be generated on macOS
- Apple-specific credentials/config files are not committed here

## Generate the Xcode project

On macOS:

```bash
brew install xcodegen
cd /path/to/my-business-idea-IOS
xcodegen generate
open MyBusinessIdea.xcodeproj
```

## Required setup on macOS before running

1. Set your Apple Development Team in Xcode signing.
2. Replace the placeholder bundle identifier if needed.
3. Add `GoogleService-Info.plist`.
4. Replace the placeholder AdMob app id in `Info.plist`.
5. Create the App Store subscriptions and update product ids in `MyBusinessIdea/Supporting/AppConfig.swift`.
6. Enable Push Notifications if you later move from local notifications to remote notifications.

Detailed finish steps are in `docs/setup_on_mac.md`.
