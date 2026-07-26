// DXO24Controller/DXO24ControllerApp.swift
//
// Application entry point. Owns the top-level window, preference storage,
// and the shared DeviceViewModel.

import SwiftUI

@main
struct DXO24ControllerApp: App {
    @AppStorage("expertiseLevel") private var expertiseLevel = "beginner"
    @StateObject private var deviceViewModel = DeviceViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deviceViewModel)
                .frame(minWidth: 1000, minHeight: 700)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {}
        }
    }
}
