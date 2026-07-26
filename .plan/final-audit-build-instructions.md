# DXO-24 Controller — Abschluss-Audit & finale Bauanleitung
## Prerequisites
- macOS 14.0 (Sonoma)
- Xcode 15.0 oder neuer
- Command Line Tools: `xcode-select --install`

## Setup in Xcode
1. **Neues Projekt:** `File > New > Project > macOS > App`.
2. **Projektoptionen:**
   - Product Name: `DXO24Controller`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - mindestens macOS 14.0 (Sonoma)
3. **Integration:** Lösche die Standarddateien von Xcode und ziehe die Ordner aus diesem Repository herein:
   - `Models/`
   - `ViewModels/`
   - `Views/`
   - `Services/`
   - `DesignSystem/`
   - `DXO24ControllerApp.swift` ersetze die Projektvorlage
   - in den Importdialogen: **Copy items if needed** und **Add to targets: DXO24Controller**

## Build-Phasen-Abhängigkeiten
- `DXO24ControllerApp.swift` hängt von `ContentView.swift` und `DeviceViewModel.swift` ab
- `ContentView.swift` hängt von `ParametersView.swift`, `CalibrationView.swift`, `FrequencyResponseView.swift`, `PresetsView.swift` ab
- alle Views hängen von den Modellen und dem `DesignSystem/Tokens.swift` ab
- `DeviceViewModel` erbt von `ObservableObject` und `DXO24Communication` und erbt durch die Views alle weiteren Abhängigkeiten

## Sandbox, Berechtigungen und Info.plist
Xcode: Target > **Signing & Capabilities** > **+ Capability**
- **App Sandbox** aktivieren
  - Outgoing Connections: **aus**
  - Incoming Connections: **aus**
  - USB: `com.apple.security.device.usb`
  - Audio Input: `com.apple.security.device.audio-input`
- **Hardened Runtime** aktivieren

`Info.plist` ergänzen:
- `Privacy - Microphone Usage Description` (`NSMicrophoneUsageDescription`): **"Wird für die Raumeinmessung benötigt."**

## Build & Run
1. Entwicklungsteam unter **Signing & Capabilities** auswählen
2. `Cmd+B` bauen
3. `Cmd+R` starten

## Bekannte Einschränkungen
- USB: Die Kommunikation nutzt aktuell den `StubCommunication`-Simulator — kein echtes Gerät wird angesprochen.
- Messmikrofon / FFT: Die Implementierung in `Services/Audio/MeasurementEngine.swift` ist konzeptionell vorhanden und erwartet macOS-Audio-Session-Berechtigungen.
- Protokoll: Die echte Gerätekommunikation erfordert eine Live-Capture-Session, siehe `.plan/protocol_spec.md`.
- Haptik-Appell: Auf macOS existiert keine öffentliche Vibrations-API; das Feedback ist rein visuell und auditiv über Systeminteraktionen realisierbar.

## Fehlerbehebung (Schnellcheckliste)
- **Der Prozess “Simulator” wurde vom System nicht geöffnet:** In Xcode > Window > Devices and Viewports prüfen. Runtime-Absturz durch fehlendes `Simulator`-Target? Prüfe ob dynamische Verknüpfungen sauber sind.
- **“Prozess nicht geöffnet” in Xcode:** Projektclean `Shift+Cmd+K`, DerivedData löschen, nochmal bauen. Prüfe ob macOS-Zielversion auf macOS 14 eingestellt ist.
- **“Keine solche Module” / Target-Abhängigkeiten fehlerhaft:** Prüfe `Build Phases > Compile Sources` und Abhängigkeitsreihenfolge: Views → ViewModels → Models → Services.
- **App hängt in Dauerschleife:** Simulator-Deadlocks werden oft durch `async`/`await`-Nebel erzeugt. Aktuell basiert die UI auf reaktiven Publishern — bei Dauerschleifen SwiftUI-Neustart erzwingen: `Cmd+.`

## Audit-Ergebnis dieser Sitzung
- `CommunicationError` ist genau einmal definiert und konsistent verwendet.
- `DXO24CommunicationProtocol` nutzt `CommunicationError` als Fehlerwurf.
- `DeviceViewModel` nutzt `@EnvironmentObject` und hängt sauber am `ContentView`.
- `ContentView` prüft `viewModel.headroomWarning` und zeigt den Hinweis an.
- `ParametersView` nutzt `Binding(get:set:)` auf dem ViewModel-Gerätezustand.
- `CalibrationView` wendet EQ-Vorschläge mit `viewModel.device` an.
- `FrequencyResponseView` bindet `Charts` mit `#if canImport(Charts)`.

## Nächste Empfehlung
Echthardware-Protokoll-Capture starten gemäß `.plan/protocol_spec.md` und `MeasurementEngine` durch echte AVAudioEngine-Taps ersetzen.
