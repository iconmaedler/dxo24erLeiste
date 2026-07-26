// DXO24Controller/Views/AmplifierView.swift
//
// Bereich für zusätzliche Endstufen (Verstärker), die extern an den DXO-24 angeschlossen sind.
// Der Nutzer definiert hier:
//   1. Wie die Endstufe verbunden ist (Daisy‑Chain, Parallel‑Out, USB, Dante, AES/EBU, 12 V Trigger …).
//   2. Welche Lautsprecher extern dazu laufen (mit Kanal, Pol, Filter, Verzögerung).
//   3. Wie sie eingestellt werden sollen (Gain, Bridged, DSP, Limiter, Schutzschaltung).
// plus / minus / Duplikat / Drag‑and‑Drop-Liste der Endstufen.
//
import SwiftUI

struct AmplifierView: View {
    @EnvironmentObject private var viewModel: DeviceViewModel
    @State private var amplifiers: [Amplifier] = []
    @State private var selectedID: UUID?
    @State private var presentError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Endstufen (Verstärker)")
                    .font(.title2.bold())
                Spacer()
                Button { addAmplifier() } label: {
                    Label("Endstufe hinzufügen", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(amplifiers.count >= 16)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            HStack(alignment: .top, spacing: 0) {
                // Liste links
                List(selection: $selectedID) {
                    ForEach(amplifiers) { amp in
                        AmplifierListRow(amp: amp)
                            .tag(amp.id)
                            .contextMenu {
                                Button("Duplizieren") { duplicate(amp) }
                                Button("Löschen", role: .destructive) { delete(amp) }
                            }
                    }
                }
                .frame(width: 260, alignment: .leading)
                .listStyle(.sidebar)

                Divider()

                // Detail rechts
                if let selID = selectedID,
                   let idx = amplifiers.firstIndex(where: { $0.id == selID }) {
                    AmplifierDetail(amp: $amplifiers[idx])
                        .padding()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Wähle eine Endstufe oder lege eine neue an.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            if let errMsg = presentError {
                Text(errMsg).foregroundStyle(.red).padding(.bottom, 8)
            }
        }
        .navigationTitle("Endstufen")
        .onAppear { reloadFromDisk() }
    }

    // MARK: - Aktionen

    private func addAmplifier() {
        let new = Amplifier(name: "Endstufe \(amplifiers.count + 1)")
        amplifiers.append(new)
        selectedID = new.id
        do { _ = try AmplifierService.save(new) }
        catch { presentError = error.localizedDescription }
    }

    private func duplicate(_ amp: Amplifier) {
        var copy = amp
        copy.id = UUID()
        copy.name = "\(amp.name) (Kopie)"
        copy.assignedSpeakers = amp.assignedSpeakers.map { var s = $0; s.id = UUID(); return s }
        amplifiers.append(copy)
        selectedID = copy.id
        do { _ = try AmplifierService.save(copy) }
        catch { presentError = error.localizedDescription }
    }

    private func delete(_ amp: Amplifier) {
        amplifiers.removeAll { $0.id == amp.id }
        if selectedID == amp.id { selectedID = nil }
        do { try AmplifierService.delete(amp) }
        catch { presentError = error.localizedDescription }
    }

    private func reloadFromDisk() {
        amplifiers = (try? AmplifierService.listAll()) ?? []
        if selectedID == nil { selectedID = amplifiers.first?.id }
    }
}

// MARK: - Listen‑Reihe

private struct AmplifierListRow: View {
    let amp: Amplifier

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: amp.connection.iconName)
                .font(.title2)
                .foregroundStyle(amp.isPowered ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(amp.name).font(.headline)
                Text("\(amp.manufacturer) \(amp.model)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(amp.channelsInUse) Kanäle • \(Int(amp.powerWattsSafe)) W • \(String(format: "%.1f", amp.gainDb)) dB")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(amp.isPowered ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail‑Editor

private struct AmplifierDetail: View {
    @Binding var amp: Amplifier

    var body: some View {
        Form {
            Section("Meta‑Daten") {
                LabeledRow("Name") {
                    TextField("Name", text: $amp.name).textFieldStyle(.roundedBorder)
                }
                LabeledRow("Hersteller") {
                    TextField("Hersteller", text: $amp.manufacturer).textFieldStyle(.roundedBorder)
                }
                LabeledRow("Modell") {
                    TextField("Modell", text: $amp.model).textFieldStyle(.roundedBorder)
                }
                LabeledRow("Seriennummer") {
                    TextField("Seriennummer", text: $amp.serial).textFieldStyle(.roundedBorder)
                }
            }

            Section("Verbindung (Verkabelung an DXO‑24)") {
                Picker("Verbindungstyp", selection: $amp.connection) {
                    ForEach(Amplifier.Connection.allCases) { c in
                        Label(c.rawValue, systemImage: c.iconName).tag(c)
                    }
                }
                .pickerStyle(.menu)

                TextField("Input‑Quelle", text: $amp.inputSource)
                    .textFieldStyle(.roundedBorder)
                    .help("z.B. „Output A\", „Dante 1”, „AES/EBU‑Kanal 3”")

                Toggle("12 V Trigger / Hauptstrom an", isOn: $amp.isPowered)
            }

            Section("Leistung & Konfiguration") {
                Stepper("Kanäle: \(amp.channels)",
                        value: $amp.channels, in: 1...8)
                    .disabled(amp.isBridged && amp.channels < 2)
                HStack {
                    Text("Leistung pro Kanal")
                    Slider(value: $amp.powerPerChannel, in: 50...8000, step: 50)
                    Text("\(Int(amp.powerPerChannel)) W")
                        .frame(width: 70, alignment: .trailing)
                }
                HStack {
                    Text("Gain")
                    Slider(value: $amp.gainDb, in: -12...12, step: 0.5)
                    Text(String(format: "%+.1f dB", amp.gainDb))
                        .frame(width: 70, alignment: .trailing)
                }
                Toggle("Bridged‑Modus (Brückenbetrieb)", isOn: $amp.isBridged)
                LabeledRow("Effektive Leistung") {
                    Text("\(Int(amp.powerWattsSafe)) W • \(amp.channelsInUse) Kanäle aktiv")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Section("Zugewiesene externe Lautsprecher") {
                ForEach($amp.assignedSpeakers) { $speaker in
                    SpeakerAssignmentRow(speaker: $speaker, maxChannels: amp.channelsInUse)
                }
                Button {
                    let next = Amplifier.SpeakerAssignment(name: "Lautsprecher \(amp.assignedSpeakers.count + 1)",
                                                            outputChannel: amp.assignedSpeakers.count + 1)
                    amp.assignedSpeakers.append(next)
                } label: {
                    Label("Lautsprecher hinzufügen", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                if amp.assignedSpeakers.isEmpty {
                    Text("Noch keine externen Lautsprecher zugewiesen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("DSP‑Einstellungen (Ziel‑Setup der Endstufe)") {
                HStack {
                    Text("Crossover (Hochpass‑Out)")
                    Slider(value: $amp.dspSettings.crossoverHighHz, in: 0...20_000, step: 10)
                    Text(String(format: "%.0f Hz", amp.dspSettings.crossoverHighHz))
                        .frame(width: 80, alignment: .trailing)
                }
                Toggle("Kompressor aktiv", isOn: $amp.dspSettings.compressorEnabled)
                if amp.dspSettings.compressorEnabled {
                    HStack {
                        Text("Threshold")
                        Slider(value: $amp.dspSettings.compressorThresholdDb, in: -30...0, step: 0.5)
                        Text(String(format: "%.1f dB", amp.dspSettings.compressorThresholdDb))
                            .frame(width: 80, alignment: .trailing)
                    }
                }
                Picker("Limiter‑Modus", selection: $amp.dspSettings.limiterMode) {
                    ForEach(Amplifier.DSPSettings.LimiterMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Limiter‑Threshold")
                    Slider(value: $amp.dspSettings.limiterThresholdDb, in: -20...0, step: 0.5)
                    Text(String(format: "%.1f dB", amp.dspSettings.limiterThresholdDb))
                        .frame(width: 80, alignment: .trailing)
                }
                Toggle("Schutzschaltung (Peak‑Protector)", isOn: $amp.dspSettings.protection)
            }

            Section("Aktionen") {
                Button {
                    save()
                } label: {
                    Label("Speichern", systemImage: "tray.and.arrow.down.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .onChange(of: amp) { _ in save() }
    }

    private func save() {
        try? AmplifierService.save(amp)
    }
}

// MARK: - Lautsprecher‑Zuweisung

private struct SpeakerAssignmentRow: View {
    @Binding var speaker: Amplifier.SpeakerAssignment
    let maxChannels: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle(isOn: $speaker.isActive) {}
                TextField("Name", text: $speaker.name).textFieldStyle(.roundedBorder)
                Picker("Kanal", selection: $speaker.outputChannel) {
                    ForEach(1...max(maxChannels, 1), id: \.self) { i in
                        Text("Ch \(i)").tag(i)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 90)
            }
            HStack {
                Toggle("Pol invertiert", isOn: $speaker.polarityInverted)
                Spacer()
                HStack {
                    Text("Highpass")
                    Slider(value: $speaker.hpFilter, in: 0...500, step: 1)
                    Text(String(format: "%.0f Hz", speaker.hpFilter))
                        .frame(width: 60, alignment: .trailing)
                }
                HStack {
                    Text("Lowpass")
                    Slider(value: $speaker.lpFilter, in: 0...20_000, step: 10)
                    Text(String(format: "%.0f Hz", speaker.lpFilter))
                        .frame(width: 60, alignment: .trailing)
                }
                HStack {
                    Text("Delay")
                    Slider(value: $speaker.delayMs, in: 0...20, step: 0.1)
                    Text(String(format: "%.1f ms", speaker.delayMs))
                        .frame(width: 60, alignment: .trailing)
                }
            }
            Divider()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helper

private struct LabeledRow<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack {
            Text(label).frame(width: 140, alignment: .leading)
            content
            Spacer()
        }
    }
}

// End of AmplifierView.swift
