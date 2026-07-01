# Gym App Agent Notes

This is a native SwiftUI Xcode project.
There is no `package.json` command layer for build or release.
Use Xcode CLI tools directly.

## Project Identity

- Project: `GymApp.xcodeproj`
- Scheme: `GymApp`
- App display name: `Stacked`
- Bundle identifier: `com.kevin.stacked`
- Apple team ID: `JU7RZ24773`
- Current known simulator app path: `/Users/zoidz123/Library/Developer/Xcode/DerivedData/GymApp-eguohfyqfgtcdzcizvhbevsoezbp/Build/Products/Debug-iphonesimulator/Stacked.app`

## Simulator Workflow

List booted simulators:

```sh
xcrun simctl list devices booted
```

Build for the simulator:

```sh
xcodebuild -project GymApp.xcodeproj -scheme GymApp -destination 'generic/platform=iOS Simulator' build
```

Install the latest simulator build onto the booted simulator:

```sh
xcrun simctl install booted /Users/zoidz123/Library/Developer/Xcode/DerivedData/GymApp-eguohfyqfgtcdzcizvhbevsoezbp/Build/Products/Debug-iphonesimulator/Stacked.app
```

Launch the app on the booted simulator:

```sh
xcrun simctl launch --terminate-running-process booted com.kevin.stacked
```

Launch directly into History when checking History UI:

```sh
SIMCTL_CHILD_UI_TEST_START_TAB=history xcrun simctl launch --terminate-running-process booted com.kevin.stacked
```

Take a simulator screenshot:

```sh
xcrun simctl io booted screenshot /tmp/gym-app-screenshot.png
```

## App Store Connect Upload Workflow

Before uploading, bump `CURRENT_PROJECT_VERSION` in `GymApp.xcodeproj/project.pbxproj`.
Apple rejects duplicate build numbers for the same marketing version.
For example, keep `MARKETING_VERSION = 1.0;` and increment build numbers like `3`, `4`, `5`.

Create a Release archive for physical iOS:

```sh
xcodebuild \
  -project GymApp.xcodeproj \
  -scheme GymApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /Users/zoidz123/Desktop/gym-app/build/Stacked.xcarchive \
  archive
```

Use the App Store Connect export options plist at `ExportOptions-AppStore.plist`.
The file should use automatic signing with team `JU7RZ24773` and `method` set to `app-store-connect`.

Upload the archive:

```sh
xcodebuild \
  -exportArchive \
  -archivePath /Users/zoidz123/Desktop/gym-app/build/Stacked.xcarchive \
  -exportOptionsPlist /Users/zoidz123/Desktop/gym-app/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates
```

A successful upload ends with:

```text
Uploaded GymApp
** EXPORT SUCCEEDED **
```

After upload succeeds, App Store Connect still needs time to process the build before it appears in TestFlight.
Do not assume processing is complete immediately after upload.

## Credential Notes

This Mac is expected to have the required Apple Developer account signed into Xcode.
Automatic signing should use team `JU7RZ24773`.
If upload fails with authentication, provisioning, or account errors, open Xcode account settings or App Store Connect credentials rather than changing app code.

## Native Swift OTA Notes

This app is native SwiftUI.
Swift code, native behavior, entitlements, permissions, and bundled assets require a new App Store or TestFlight build.
Remote updates should be limited to data, content, feature flags, or config consumed by already-shipped code.
Do not plan on React Native or Expo-style code push for this app unless the app architecture changes substantially.
