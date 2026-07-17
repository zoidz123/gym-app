# Stacked

Stacked is a native SwiftUI workout tracker for planning routines, logging active workouts, and reviewing workout history.
It supports reusable workout templates, supersets, previous-set hints, calendar history, and a searchable exercise catalog.

## Requirements

- macOS with Xcode 26 or newer
- iOS 17 or newer
- Git

## Setup

Clone the repository:

```sh
git clone https://github.com/zoidz123/gym-app.git
cd gym-app
```

The simulator build does not require an Apple Developer account:

```sh
xcodebuild \
  -project GymApp.xcodeproj \
  -scheme GymApp \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run tests on an installed simulator by replacing the destination name if needed:

```sh
xcodebuild \
  -project GymApp.xcodeproj \
  -scheme GymApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Configuration and signing

No API keys or service credentials are required.
Unsigned simulator builds work with the commands above.
For signed device or archive builds, supply your Apple team and signing identity locally through Xcode or command-line build settings.

For an App Store export, copy `ExportOptions-AppStore.example.plist` to the ignored `ExportOptions-AppStore.plist`, replace `YOUR_TEAM_ID`, and keep the completed file local.

## Data and privacy

Workout data is stored only on device in the app's Application Support directory as `GymApp/gym-data.json`.
Existing on-device data is not overwritten by repository updates.
Fresh installs start with an empty workout plan and guide the user through creating a workout in the app.
The bundled exercise catalog comes from `exercemus/exercises`; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for its license and attribution.

## Repository structure

- `GymApp/` contains the application source, assets, and exercise catalog.
- `GymAppTests/` contains unit tests.
- `GymApp.xcodeproj/` contains the Xcode project.

## License and contributions

No project license has been selected yet.
Copyright law therefore reserves all rights to the project owner, and reuse or redistribution is not currently granted.
External contributions are not being accepted until a license and contribution policy are chosen.
