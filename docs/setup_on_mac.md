# Finish on Mac

This repository is intentionally prepared so the remaining platform work happens on macOS with Xcode.

## 1. Generate the project

```bash
brew install xcodegen
xcodegen generate
open MyBusinessIdea.xcodeproj
```

## 2. Signing

- Select the `MyBusinessIdea` target
- Add your Apple Developer Team
- Confirm the bundle id

## 3. Firebase

- Create the iOS app in Firebase with the final bundle id
- Download `GoogleService-Info.plist`
- Add it to `MyBusinessIdea/Resources`

The app is coded to skip Firebase bootstrap when the plist is missing, so the repo remains safe in source control.

## 4. AdMob

- Replace `GADApplicationIdentifier` in `MyBusinessIdea/Resources/Info.plist`
- Create iOS ad units for:
  - inline banner on Home
  - inline banner before action plan
  - interstitial for generation flow
  - rewarded for "more ideas"

## 5. StoreKit / App Store Connect

Set real product ids in `MyBusinessIdea/Core/Config/AppConfig.swift`:

- monthly premium
- yearly premium

Then create the matching subscriptions in App Store Connect.

## 6. QA checklist

- Login / register / recovery
- Manual draft save
- Generate plan
- Update plan
- Favorites sync
- Export text
- Export PDF with premium active
- Review prompt after second generated idea
- Notification prompt after third generated idea
- Tap local notification and verify it opens the prefilled draft editor
- Rewarded / interstitial / banner ads
- Language update request to backend

## 7. Recommended next technical step

If you want cross-platform subscription entitlements, move premium state to the backend or to a service such as RevenueCat. The current iOS scaffold uses local StoreKit entitlement checks only.
