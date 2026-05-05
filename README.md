# Digital Tower

Digital Tower is a visionOS TestFlight app for spatial aviation discovery. It is not for navigation, ATC, dispatch, flight safety, or operational decisions.

## Requirements

- Xcode 26.4.1 or newer with visionOS SDK 26.4
- XcodeGen available as `xcodegen`
- Swift 6.0
- Apple Developer Team ID for signing
- Authorized aviation backend that implements the app contract below

## Data Contract

The app never talks directly to third-party aviation providers. It connects only to your authorized backend.

- `GET /v1/bootstrap?airport=KJFK`
  - Returns `AviationSnapshot`: airport, weather, alerts, initial flights, replay events, and freshness metadata.
- `GET /v1/flights/stream?airport=KJFK`
  - Server-Sent Events.
  - Supported event names: `flight.upsert`, `flight.delete`, `weather.update`, `alert.upsert`, `alert.delete`, `heartbeat`.
- Request auth:
  - `Authorization: Bearer <token>`
  - Configure with `AVIATION_API_BASE_URL` and `AVIATION_API_TOKEN` build settings, or set `AviationAPIToken` in user defaults for local debugging.

Release/TestFlight builds do not fall back to sample flight data when the backend is missing. Debug builds use `SampleAviationDataProvider` only as a local development fallback.

## Build

Regenerate the Xcode project after changing `project.yml`:

```sh
xcodegen generate
```

Build without signing:

```sh
xcodebuild -project DigitalTower.xcodeproj -scheme DigitalTower -configuration Debug -sdk xros26.4 -destination generic/platform=visionOS -derivedDataPath /tmp/DigitalTowerDerived build CODE_SIGNING_ALLOWED=NO
```

Run unit tests:

```sh
xcodebuild test -project DigitalTower.xcodeproj -scheme DigitalTower -destination 'platform=visionOS Simulator,name=Apple Vision Pro' -derivedDataPath /tmp/DigitalTowerTests
```

## TestFlight Checklist

- Provide `DEVELOPMENT_TEAM`, final bundle ID, signing profile, and export options.
- Provide final visionOS App Icon art; current asset catalog is a build-ready placeholder.
- Provide privacy policy URL, support URL, TestFlight review notes, and data source authorization notes in App Store Connect.
- Verify the backend is reachable by App Review/TestFlight testers.
- Run a Release build on device and record frame pacing, CPU/GPU, memory, immersive open/dismiss, and 300/1000-flight density behavior.
- Confirm no UI copy claims navigation, ATC, dispatch, flight safety, or operational decision support.

## Privacy Notes

v1 does not request location, camera, microphone, sensor, or background permissions. If future releases add any of those capabilities, update Info.plist usage strings, entitlements, privacy manifests, and App Store privacy nutrition details before submission.
