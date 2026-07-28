// DXO24Controller/Views/WelcomeTourView.swift
//
// Interactive welcome tour that guides the user through all major app features.
// Uses SwiftUI overlays with step-by-step highlighting and explanations.
//
import SwiftUI

struct WelcomeTourView: View {
    @State private var currentPage = 0
    @State private var showingTour = true
    @Environment(\.dismiss) private dismiss
    
    // Define all tour steps covering each major feature
    let steps: [TourStep] = [
        TourStep(
            title: "Willkommen bei DXO-24 Controller",
            icon: "house.fill",
            description: "Dies ist die Hauptseite Ihrer DXO-24 Steuerungsplattform. Hier können Sie rasch auf alle wichtigen Funktionen zugreifen.",
            hint: "Tippe auf die Tabs unten oder verwende die Tastaturkürzel ⌘1-⌘4"
        ),
        TourStep(
            title: "Parameter Panel",
            icon: "slider.horizontal.2",
            description: "Hier steuern Sie die wichtigsten Parameter: Lautsprecherpegel, Crossover-Frequenz, EQ-Bänder und Zeitverzögerungen.",
            hint: "Drehen Sie die Schieber oder tippen Sie direkt auf die Werte für präzise Einstellungen"
        ),
        TourStep(
            title: "Kalibrierung",
            icon: "flame",
            description: "Der Kalibrier-Assistent leitet Sie schrittweise durch Raumvermessung, Lautsprecherkonfiguration und automatische EQ-Empfehlungen.",
            hint: "Starten Sie mit Space-bar oder dem Button 'Messung Starten'"
        ),
        TourStep(
            title: "Raum-Planer",
            icon: "person.fill.happy",
            description: "Platzieren Sie Lautsprecher, Möbel und Hörposition im virtuellen 3D-Raum zur akustischen Analyse.",
            hint: "Ziehen Sie Objekte ins Szenenfenster und passen Sie Position, Rotation und Größe an"
        ),
        TourStep(
            title: "Presets",
            icon: "folder.circle",
            description: "Speichern und laden Sie vollständige Geräteeinstellungen mit allen Parametern und Raumdaten.",
            hint: "Tippe + für neues Preset, Drag-Drop zum Speichern oder Import aus Datei"
        ),
        TourStep(
            title: "FFT Analyzer",
            icon: "waveform.path.max.min",
            description: "Echtzeit-Frequenzanalyse während Messungen und Playback mit Live-Chart Visualisierung.",
            hint: "Wählen Sie FFT-Größe (64-8192 Punkte) für mehr Auflösung oder höhere Refresh-Rate"
        )
    ]
    
    var body: some View {
        if showingTour {
            ZStack {
                // Dimmed background of actual app
                Color.black.opacity(0.5)
                
                // Tour content
                VStack(spacing: 20) {
                    // Step card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: steps[currentPage].icon)
                                .font(.system(size: 64))
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(steps[currentPage].title)
                                    .font(.title2.bold())
                                Text("Schritt \(currentPage + 1) / \(steps.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(steps[currentPage].description)
                            .font(.body)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        
                        if let hint = steps[currentPage].hint {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .foregroundColor(.accentColor)
                                Text(hint)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Navigation controls
                    HStack(spacing: 24) {
                        Button(action: previousPage) {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                        }
                        .disabled(currentPage == 0)
                        .opacity(currentPage == 0 ? 0.3 : 1)
                        
                        Spacer()
                        
                        Button(action: nextPage) {
                            Image(systemName: "chevron.right")
                                .font(.headline)
                        }
                        .disabled(currentPage == steps.count - 1)
                        .opacity(currentPage == steps.count - 1 ? 0.3 : 1)
                    }
                    
                    // Progress indicators
                    HStack(spacing: 8) {
                        ForEach(0..<steps.count) { index in
                            Circle()
                                .fill(index == currentPage ? AccentColor : Gray.opacity(0.3))
                                .frame(width: 12, height: 12)
                        }
                    }
                    
                    // Bottom actions
                    HStack(spacing: 16) {
                        Button("Überspringen") {
                            showingTour = false
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button(currentPage == steps.count - 1 ? "Fertig" : "Weiter") {
                            if currentPage == steps.count - 1 {
                                showingTour = false
                            } else {
                                nextPage()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                .frame(maxWidth: 500)
                .background(.ulcerClear.thickMaterial)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding()
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
    
    private func previousPage() {
        if currentPage > 0 { currentPage -= 1 }
    }
    
    private func nextPage() {
        if currentPage < steps.count - 1 { currentPage += 1 }
    }
}

extension WelcomeTourView {
    struct TourStep: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let description: String
        let hint: String?
    }
}

// Preview for Xcode
#Preview("Welcome Tour") {
    WelcomeTourView()
}

// End of WelcomeTourView.swift