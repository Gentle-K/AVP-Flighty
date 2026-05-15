# DigitalTower Visual Standards

This file is the production QA gate for the Digital Tower immersive scene. A build is not acceptable just because it compiles. The default visionOS Simulator scene must pass screenshot review against this standard.

## A. Aircraft Model Standard

- 100% of visible aircraft in the default scene must use bundled user-provided model asset `DigitalTower/Resources/Models/A380.glb`.
- 0 yellow/gold placeholder aircraft are allowed.
- 0 procedural airplane meshes are allowed in the production scene.
- Aircraft must have correct forward direction.
- Aircraft must not be upside down or sideways.
- Aircraft scale must be believable and consistent.
- If `A380.glb` fails to load, production aircraft rendering must be disabled; do not silently substitute USDZ, meshbin, or procedural aircraft.

## B. Scene Readability Standard

- Default aircraft count must be 8-12 maximum.
- Active aircraft count must include:
  - 1 landing aircraft
  - 1 takeoff aircraft
  - 1 go-around aircraft
  - 1 holding aircraft
  - 4-8 background aircraft
- No aircraft should overlap another aircraft at scene start.
- No more than 2 aircraft may be on the runway at the same time.
- The center runway area must remain readable.
- Text labels must not overlap the runway centerline or each other.

## C. Route Visual Standard

- Arrival/final approach route: cyan/blue.
- Departure/takeoff route: amber/orange.
- Go-around route: red/orange.
- Holding pattern: purple dashed racetrack.
- Altitude rings: thin grey, low opacity.
- Runway guide lights: green/white with clear centerline.
- Past trails: solid fading ribbons.
- Future paths: dashed or dotted.
- Only selected/key aircraft routes should be bright.
- Background aircraft routes should be subtle.

## D. Runway Standard

- Runway must be clearly visible.
- Runway threshold must be visible.
- Centerline lights must be visible.
- Approach direction must align with runway.
- Takeoff aircraft must start from the runway.
- Landing aircraft must touch down on the runway, not beside it.

## E. Motion Standard

- Aircraft must not teleport.
- Aircraft heading must follow path tangent.
- Pitch must match climb/descent:
  - final approach: slight nose down or level
  - flare: slight nose up
  - takeoff roll: level
  - rotation: nose up
  - climb: nose up
  - go-around: nose up
- Roll must appear during turns.
- Trails must update smoothly.
- Landing and takeoff must be visually understandable within 30 seconds of watching.

## F. UI Standard

- No large dashboard may dominate the immersive scene.
- UI should occupy less than 20% of default view.
- Labels must be contextual and minimal.
- Key aircraft may have labels; background aircraft should not all have labels.

## G. Screenshot Standard

A simulator screenshot must clearly show:

- user-provided `A380.glb` aircraft models
- clear runway
- one landing route
- one takeoff route
- one holding route
- one go-around route
- visible but non-chaotic altitude rings
- no gold placeholder aircraft
- no cluttered runway center

## Route Types

Every rendered route must use one of these semantic types:

```swift
enum RouteVisualType {
    case arrivalFinal
    case landingRollout
    case departureTakeoff
    case departureClimb
    case holding
    case goAround
    case altitudeRing
    case runwayGuide
    case backgroundTraffic
}
```

Route colors must come from a central style table. Random route colors hardcoded in scattered scene code are not acceptable.

## QA Rubric

Total score: 100 points.

- Aircraft asset correctness: 20 points
  - 20: all visible aircraft use `A380.glb`
  - 10: some use `A380.glb`, some placeholders remain
  - 0: obvious placeholders or wrong model still visible
- Scene readability: 20 points
  - 20: clean, organised, no central clutter
  - 10: partially readable but still crowded
  - 0: chaotic/debug-looking
- Route clarity: 20 points
  - 20: arrival/departure/holding/go-around immediately distinguishable
  - 10: routes exist but meaning unclear
  - 0: random lines or unclear route system
- Runway operation logic: 20 points
  - 20: one landing and one takeoff clearly tied to runway
  - 10: landing/takeoff exist but not convincing
  - 0: aircraft not connected to runway logic
- Visual polish: 10 points
  - 10: cinematic, polished, readable
  - 5: acceptable but rough
  - 0: prototype/debug look
- UI minimalism: 10 points
  - 10: UI does not dominate
  - 5: some clutter
  - 0: panels/labels dominate scene

Passing threshold:

- Minimum score: 90/100.
- Aircraft asset correctness must be 20/20.
- Runway operation logic must be at least 18/20.
- Route clarity must be at least 18/20.

## Hard Failure Conditions

Any one of these is a failure regardless of total score:

- Any visible yellow/gold placeholder aircraft.
- Any procedural aircraft visible in the default scene.
- Any visible aircraft not loaded from `DigitalTower/Resources/Models/A380.glb`.
- Landing aircraft not aligned with runway.
- Takeoff aircraft not starting from runway.
- Scene still looks like a debug sandbox.
- More than 12 aircraft in the default view.
- Unreadable runway center.
- Overlapping aircraft on runway.
- Unclear landing/takeoff route.
- Cluttered debug labels.
- Build failure.
- Simulator launch failure or blank immersive scene.

## Required QA Loop

1. Run `xcodebuild -list` and identify the correct scheme.
2. Build the app for Apple Vision Pro Simulator.
3. Fix build errors until successful.
4. Launch in Apple Vision Pro Simulator.
5. Capture a simulator screenshot if possible.
6. Review the screenshot against this file.
7. Score the result from 0 to 100.
8. If score is below 90 or any hard failure exists, apply a focused fix and repeat.

Final reporting must include final score, screenshot path, build status, simulator status, changed files, confirmation that no placeholder aircraft remain, and confirmation that landing/takeoff/holding/go-around are visible and readable.
