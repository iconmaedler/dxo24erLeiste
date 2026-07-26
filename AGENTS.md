# AGENTS.md

## Repository overview

DXO24Controller is a macOS SwiftUI application for configuring a DXO-24 audio
controller. The Xcode project is `DXO24Controller.xcodeproj` and the app target
and scheme are both named `DXO24Controller`.

Keep responsibilities separated:

- `Models/` contains validated, `Codable` domain types.
- `Views/` contains SwiftUI presentation and user interaction.
- `ViewModels/` owns observable UI state and coordinates services.
- `Services/CalculationService.swift` contains pure room and audio calculations.
- `Services/Communication/` contains the `DXO24Communication` boundary and
  transport implementations.
- `Services/Audio/` contains sweep generation and measurement processing.
- `DesignSystem/` contains shared visual tokens and components.
- `scripts/` contains release packaging helpers.
- `.github/workflows/` contains build and release automation.

## Build and validation

Run these commands from the repository root on macOS with Xcode installed:

```sh
xcodebuild -project DXO24Controller.xcodeproj \
  -scheme DXO24Controller \
  -destination 'platform=macOS' build
```

The repository currently has no test target. Do not claim test coverage unless
one is added and executed. For a release archive, use:

```sh
bash scripts/package-dmg.sh
```

The packaging script currently creates an unsigned, unnotarized development
DMG; it is not a production release pipeline.

## Development guidance

- Make focused changes and preserve the SwiftUI MVVM separation.
- Keep calculations deterministic and testable; avoid putting domain math in
  views or view models.
- Depend on `DXO24Communication` rather than coupling UI code to a concrete
  transport.
- Propagate communication, audio, and persistence failures to the UI instead
  of silently swallowing them.
- Avoid force unwraps and `try!` in production paths.
- Consider cancellation, throttling, and main-actor isolation for commands
  triggered by rapidly changing controls.
- Update the Xcode project whenever adding or removing Swift source files.
- Preserve valid `XCBuildConfiguration` syntax: each configuration must have a
  `Debug` or `Release` name and properly closed object delimiters.

## Production-readiness constraints

The current codebase is a prototype. `StubCommunication` only mutates
in-memory state, and the audio measurement services contain simulated transfer
function paths. Do not represent either path as hardware communication or a
real microphone measurement.

Before shipping, work must include:

1. A real USB transport and device-discovery/handshake implementation behind
   `DXO24Communication`.
2. A microphone capture, cross-correlation, and FFT measurement pipeline.
3. Removal or debug-only isolation of simulation/stub behavior.
4. Unit tests for protocol encoding/decoding, model validation, calculations,
   and mocked communication.
5. A real reverse-DNS bundle identifier and appropriate sandbox/hardened
   runtime entitlements.
6. Signed archives, Developer ID/App Store export configuration, notarization,
   and stapling in the release workflow.

Treat `com.example.*`, unsigned archives, unnotarized DMGs, and simulated
measurement data as release blockers.

## Change checklist

Before finishing a change:

- Build the app with the command above when the environment supports macOS
  tooling.
- Inspect the diff and ensure unrelated files were not changed.
- Update documentation when commands, architecture, or release behavior
  changes.
- Never commit certificates, provisioning profiles, API keys, signing
  passwords, or other credentials.
