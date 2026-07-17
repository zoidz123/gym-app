# Gym App Agent Notes

This is a native SwiftUI Xcode project.
There is no package-manager command layer for build or release.
Use Xcode command-line tools directly.

## Project

- Project: `GymApp.xcodeproj`
- Scheme: `GymApp`
- App display name: `Stacked`
- Minimum iOS version: iOS 17

Initialize the workout-plan submodule before building:

```sh
git submodule update --init --recursive
```

Build without requiring an Apple Developer account:

```sh
xcodebuild \
  -project GymApp.xcodeproj \
  -scheme GymApp \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run tests on an available iOS simulator:

```sh
xcodebuild \
  -project GymApp.xcodeproj \
  -scheme GymApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Signing

No Apple team identifier, certificate, provisioning profile, or account credential belongs in Git.
Pass local signing settings through Xcode or command-line build settings when a signed device build is required.
For App Store exports, copy `ExportOptions-AppStore.example.plist` to the ignored `ExportOptions-AppStore.plist` and fill in local account details.

## Native Swift Updates

Swift code, native behavior, entitlements, permissions, and bundled assets require a new App Store or TestFlight build.
Remote updates should be limited to data, content, feature flags, or configuration consumed by already-shipped code.
