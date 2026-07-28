// DXO24Controller/Views/ContentView.swift
//
// Haupt-Navigationsinterface und Home-View für das DXO-24 Controller.
// Implementiert Keyboard Shortcuts und zentrale Steuerungspunkte.
//
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: DeviceViewModel
    @State private var selectionTab: Tab = .parameters
    @State private var showPreferences = false
    
    enum Tab: String, CaseIterable, Identifiable {
        case parameters          = "Parameter"       // ⌘1
        case calibration         = "Kalibrierung"    // ⌘2
        case roomPlanner         = "Raum-Planer"     // ⌘3
        case presets             = "Presets"         // ⌘4
        
        var id: Self { self }
        
        var body: some View {
            switch self {
            case .parameters: return parametersView()
            case .calibration: return CalibrationView()
            case .roomPlanner: return RoomPlannerView()
            case .presets: return PresetsView()
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(Tab.allCases) { tab in
                NavigationLink(tab.rawValue, value: tab)
                    .tag(tab, selection: $selectionTab)
            }
            .navigationTitle("DXO-24 Controller")
            .toolbar {
                Button("Einstellungen", systemImage: "gear") {
                    showPreferences = true
                }
            }
        } content: {
            Group {
            switch selectionTab {
            case .parameters:
                Text("Parameteransicht hier").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .calibration:
                Text("Kalibrierung hier").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .roomPlanner:
                Text("Raum-Planer hier").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .presets:
                Text("Presets hier").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            }
        }
        .navigationTitle("DXO-24 Controller")
        .sheet(isPresented: $showPreferences) {
            PreferencesView(shortcutRegistry: KeyboardShortcutRegistry.shared)
        }
        // Register global shortcuts at app level
        .onAppear { registerGlobalShortcuts() }
    }
    
    private func registerGlobalShortcuts() {
        // In a real implementation, you'd install global event monitors
        // For SwiftUI macOS apps, use NXEventMonitor or AppKit's NSCommandTap
        print("Global shortcuts registered")
    }
    
    private func parametersView() -> some View {
        ParametersView(expertise: .intermediate)
            .onAppear { viewModel.updateHeadroomWarning() }
    }
}

struct PreferencesView: View {
    @ObservedObject var registry: KeyboardShortcutRegistry
    @State private var customShortcuts: [KeyboardShortcutRegistry.Action: String] = [:]
    
    var body: some View {
        Form {
            Section("Tastaturkürzel") {
                ForEach(KeyboardShortcutRegistry.Action.allCases) { action in
                    HStack {
                        Text(action.localizedName)
                        Spacer()
                        TextField("Kürzel", text: $customShortkeys[action, default: action.shortcutString])
                            .frame(width: 150)
                    }
                }
            }
            Section("Hinweis") {
                Text("Kurzel können hier angepasst werden. Standardmäßige gelten Cmd+S, Cmd+O etc.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 600, height: 400)
        .navigationTitle("Einstellungen")
    }
}

// End of ContentView.swift