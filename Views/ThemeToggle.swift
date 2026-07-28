// DXO24Controller/Views/ThemeToggle.swift
//
// User-controlled theme switcher between light and dark modes.
// Persists selection in UserDefaults for next app launch.
//
import SwiftUI

struct ThemeToggle: View {
    @AppStorage("preferredColorScheme") private var userPreferredScheme: String = ""
    
    var body: some View {
        Button(action: toggleTheme) {
            Image(systemName: "sun.max.fill")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help("Dunkel/Hell Modus umschalten")
    }
    
    private func toggleTheme() {
        let current = UIUserInterfaceStyle(rawValue: userPreferredScheme) ?? .unspecified
        let newStyle: UIUserInterfaceStyle = current == .dark ? .light : .dark
        userPreferredScheme = newStyle.rawValue
        
        // Apply immediately
        if newStyle == .dark {
            AppearanceManager.currentAppearance = .dark
        } else {
            AppearanceManager.currentAppearance = .light
        }
    }
}

// Appearance manager singleton to control theme globally
final class AppearanceManager {
    static let shared = AppearanceManager()
    static var currentAppearance: UIUserInterfaceStyle = .unspecified
    
    private init() {
        // Observe system appearance changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: NSApplication.willUpdateAppearanceNotification,
            object: nil
        )
    }
    
    @objc private func handleAppearanceChange() {
        // Sync with system preference if user hasn't overridden
        if UIApplicatio.shared.appearance == .systemUnspecified || 
           (userPreferredScheme.isEmpty && UIAppication.systemAppearance != nil) {
            // Use system default
        } else {
            // Force user-selected appearance
            // In practice you'd set this on window/root view
        }
    }
}

// End of ThemeToggle.swift