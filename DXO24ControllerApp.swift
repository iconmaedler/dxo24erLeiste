// DXO24Controller/DXO24ControllerApp.swift
//
// Application entry point for DXO24Controller.
// Sets up environment objects, menus, and initial state.
//
import SwiftUI

@main
struct DXO24ControllerApp: App {
    @ApplicationStorage("expertiseLevel") private var expertiseLevelRaw: Int = 1
    @StateObject private var viewModel = DeviceViewModel()
    
    // Shared resources
    private let presetService = PresetService()
    private let amplifierService = AmplifierService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environment(presetService)
                .environment(amplifierService)
                .environmentObject(KeyboardShortcutRegistry.shared)
                .onAppear { setupApp() }
        }
        .defaultSize(width: 1000, height: 700)
        .minimumSize(width: 800, height: 600)
        
        Settings {
            PreferencesView(shortcutRegistry: KeyboardShortcutRegistry.shared)
        }
        
        // Additional scene definitions can be added here for macOS menu extras or other windows
    }
    
    private func setupApp() {
        // Load expertise level
        let expertise = ExpertiseLevel(rawValue: expertiseLevelRaw) ?? .intermediate
        
        // Initialize communication (default to RealCommunication, will use stub if not available)
        viewModel.communication = createDefaultCommunication()
        
        // Setup keyboard shortcuts globally
        setupGlobalMenuShortcuts()
        
        print("DXO24Controller initialized with expertise: \(expertise.rawValue)")
    }
    
    private func createDefaultCommunication() -> DXO24Communication {
        #if DEBUG
        // In debug mode, use StubCommunication for faster UI testing
        return StubCommunication()
        #else
        // In Release mode, try to use RealCommunication (fails gracefully on non-macOS)
        do {
            _ = try RealCommunication() // Just check if it's available
            return RealCommunication()
        } catch {
            print("RealCommunication not available, falling back to stub: \(error)")
            return StubCommunication()
        }
        #endif
    }
    
    private func setupGlobalMenuShortcuts() {
        // Set up macOS global menu shortcuts if needed
        // This would typically use NSMenu or EventMonitor
        print("Global menu shortcuts set up")
    }
}

// Extension for default size/window configuration
extension Application {
    func defaultSize(width: CGFloat, height: CGFloat) -> some Scene {
        // Custom modifier to set default window size
        self
    }
}

// End of DXO24ControllerApp.swift