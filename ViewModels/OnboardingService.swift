// DXO24Controller/ViewModels/OnboardingService.swift
//
// Service for managing application onboarding and welcome tour state.
// Tracks whether user has seen the initial tour and provides persistent configuration.
//
import Foundation

final class OnboardingService: ObservableObject {
    static let shared = OnboardingService()
    
    // Key for UserDefaults persistence
    private let tourSeenKey = "hasSeenWelcomeTour"
    
    // Whether the welcome tour should be shown on next launch
    var shouldShowTour: Bool {
        get { !UserDefaults.standard.bool(forKey: tourSeenKey) }
        set { UserDefaults.standard.set(!newValue, forKey: tourSeenKey) }
    }
    
    // First run flag (app version first launched)
    var isFirstRun: Bool {
        let lastVersion = UserDefaults.standard.string(forKey: "lastAppVersion")
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as String ?? "0.0.0"
        
        if lastVersion != currentVersion {
            UserDefaults.standard.set(currentVersion, forKey: "lastAppVersion")
            return true
        }
        return false
    }
    
    // Count of total launches
    var launchCount: Int {
        get { UserDefaults.standard.integer(forKey: "launchCount") + 1 }
        set { UserDefaults.standard.set(newValue, forKey: "launchCount") }
    }
    
    // Get preferred color scheme preference
    var preferredColorScheme: UIUserInterfaceStyle {
        get {
            let raw = UserDefaults.standard.string(forKey: "preferredColorScheme") ?? ""
            return UIUserInterfaceStyle(rawValue: raw) ?? .unspecified
        }
        set { UserDefaults.standard.setValue(rawValue, forKey: "preferredColorScheme") }
    }
    
    // Initialize service - check if we need to show tour
    init() {
        launchCount += 1
        print("DXO24Controller launch #\(launchCount)")
        
        if isFirstRun {
            // Show additional setup on first run only
            print("First run - prompting initial setup...")
        }
    }
    
    // Mark tour as seen
    func markTourAsSeen() {
        UserDefaults.standard.set(true, forKey: tourSeenKey)
        print("Welcome tour marked as seen")
    }
    
    // Reset onboarding state (for testing)
    func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: tourSeenKey)
        UserDefaults.standard.removeObject(forKey: "lastAppVersion")
        UserDefaults.standard.set(0, forKey: "launchCount")
        print("Onboarding state reset for testing")
    }
}

// Extension for easy access from Views
extension View {
    /// Attach onboarding observer to this view
    func onboardingObserver() -> some View {
        self
            .environmentObject(OnboardingService.shared)
    }
}

// End of OnboardingService.swift