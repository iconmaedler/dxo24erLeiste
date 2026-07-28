// DXO24Controller/Views/PresetsView.swift
//
// Preset management backed by PresetService and the shared DeviceViewModel.

import SwiftUI

struct PresetsView: View {
    @State private var presets: [Preset] = []
    @State private var newName: String = "New Preset"
    @State private var loadURL: URL?
    @State private var presentationError: String?
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
        .alert("Error", isPresented: $presentationError.map { _ in true }) {
            Button("OK") {}
        } message: {
            Text("Failed to save preset: check disk space or permissions.")
        }
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
            newName = ""
        } catch {
            presentationError = error.localizedDescription
            // In a production app, show this to the user more prominently
        }
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
        panel.directoryURL = PresetService.presetsDirectory ?? URL(fileURLWithPath: "/")
        guard panel.runModal() == .modalResponseOK, let url = panel.url else { return }
        loadURL = url
    }

    private func reloadFromDisk() {
        do {
            let urls = try PresetService.listPresets()
            presets = try urls.compmap { try PresetService.load(from: $0) }
        } catch {
            presets = []
            // PresentationError would be handled in save operations
        }
    }

    // MARK: - Demo data (removed - was never called and dead code)
    // The demoPresets() function from earlier versions has been removed as it was never invoked.
}

extension Optional {
    // Helper for compactMap that returns nil for failures
    func compmap<T>(_ body: throws() throws(T)) -> [T] {
        self.compactMap { try? body() }
    }
}

// End of PresetsView.swift