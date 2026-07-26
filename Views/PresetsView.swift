// DXO24Controller/Views/PresetsView.swift
//
// Preset management backed by PresetService and the shared DeviceViewModel.

import SwiftUI

struct PresetsView: View {
    @State private var presets: [Preset] = []
    @State private var newName: String = "New Preset"
    @State private var loadURL: URL?
    @EnvironmentObject private var viewModel: DeviceViewModel

    var body: some View {
        List {
            ForEach(presets) { preset in
                VStack(alignment: .leading) {
                    Text(preset.name).font(.headline)
                    Text("\(preset.deviceState.presetName) • Modified \(preset.modifiedAt, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: delete)
        }
        .toolbar {
            TextField("Preset name", text: $newName)
            Button("Save") { saveCurrent() }
            Button("Load") { loadSelected() }
            Button("Import") { importSelected() }
        }
        .padding()
        .onAppear { reloadFromDisk() }
    }

    // MARK: - Actions

    private func delete(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
    }

    private func saveCurrent() {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let preset = Preset(name: newName, deviceState: viewModel.device, roomParameters: nil)
        presets.append(preset)
        do {
            try PresetService.save(preset)
        } catch {
            // In a later iteration, surface this to the UI.
        }
        newName = ""
    }

    private func loadSelected() {
        guard let first = presets.first else { return }
        viewModel.device = first.deviceState
        viewModel.updateHeadroomWarning()
    }

    private func importSelected() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.directoryURL = PresetService.presetsDirectory
        guard panel.runModal() == .modalResponseOK, let url = panel.url else { return }
        loadURL = url
    }

    private func reloadFromDisk() {
        presets = (try? PresetService.listPresets().compactMap { try? PresetService.load(from: $0) }) ?? []
    }

    // MARK: - Demo data

    private static func demoPresets() -> [Preset] {
        [
            Preset(name: "Flat", deviceState: .flatPreset),
            Preset(name: "DJ Standard", deviceState: {
                var d: DXO24Device = .flatPreset
                d.crossoverFrequency = 100
                d.crossoverSlope = 24
                d.outputLevel = 0
                d.inputLevel = -6
                return d
            }()),
            Preset(name: "Speech", deviceState: {
                var d: DXO24Device = .flatPreset
                d.crossoverFrequency = 120
                d.crossoverSlope = 48
                d.limiterThreshold = -6
                return d
            }()),
        ]
    }
}
