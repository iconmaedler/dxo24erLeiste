// DXO24Controller/Views/ContentView.swift
//
// Root application window using NavigationSplitView with sidebar navigation.
// Wires the shared DeviceViewModel and exposes headroom warnings in the detail area.

import SwiftUI

struct ContentView: View {
    @AppStorage("expertiseLevel") private var expertiseRaw = "beginner"
    @State private var selectedSidebar: String = "home"
    @EnvironmentObject private var viewModel: DeviceViewModel

    private var expertise: ExpertiseLevel {
        ExpertiseLevel(rawValue: expertiseRaw) ?? .beginner
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebar) {
                Label("Home", systemImage: "house.fill").tag("home")
                Label("Parameters", systemImage: "dial.medium.fill").tag("parameters")
                Label("Calibration", systemImage: "mic.fill").tag("calibration")
                Label("Frequency Response", systemImage: "waveform.path").tag("response")
                Label("Presets", systemImage: "folder.fill").tag("presets")
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .listStyle(.sidebar)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    switch selectedSidebar {
                    case "home": HomeView(expertise: expertise)
                    case "parameters": ParametersView(expertise: expertise)
                    case "calibration": CalibrationView()
                    case "response": FrequencyResponseView()
                    case "presets": PresetsView()
                    default: HomeView(expertise: expertise)
                    }
                }
                .navigationTitle(titleFor(selectedSidebar))
                if let warning = viewModel.headroomWarning {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(warning)
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(.orange.opacity(0.08))
                }
            }
            .toolbar {
                Picker("Expertise", selection: $expertiseRaw) {
                    ForEach(ExpertiseLevel.allCases, id: \.self) { level in
                        Text(level.localizedName).tag(level.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
        }
        .frame(minWidth: 1024, minHeight: 720)
    }

    @ViewBuilder
    private func titleFor(_ selection: String) -> String {
        switch selection {
        case "home": return "DXO-24 Controller"
        case "parameters": return "Parameters"
        case "calibration": return "Room Calibration"
        case "response": return "Frequency Response"
        case "presets": return "Presets"
        default: return "DXO-24 Controller"
        }
    }
}

struct HomeView: View {
    let expertise: ExpertiseLevel

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("DXO-24 Controller").font(.largeTitle.bold())
            Text("Native macOS control for the Omnitronic DXO-24").foregroundStyle(.secondary)
            Divider()
            Text("Current mode: \(expertise.localizedName)").font(.headline)
            Text(
                expertise == .beginner
                ? "Beginner mode shows essential controls only."
                : expertise == .intermediate
                ? "Intermediate mode adds phase and crossover slopes."
                : "Expert mode exposes raw values and advanced filter options."
            )
            .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(DS.Spacing.lg)
    }
}
