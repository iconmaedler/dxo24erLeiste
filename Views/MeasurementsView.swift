// DXO24Controller/Views/MeasurementsView.swift
//
// Comprehensive measurement dashboard integrating FFT visualization, analysis tools,
// and calibration workflow. Unified entry point for all audio measurement activities.
//
import SwiftUI
import Charts

struct MeasurementsView: View {
    @EnvironmentObject private var viewModel: DeviceViewModel
    
    // Tab selection within Measurements
    @State private var measurementTab: MeasurementTab = .liveAnalyzer
    
    enum MeasurementTab: String, CaseIterable, Identifiable {
        case liveAnalyzer = "Live Analyzer"
        case calibration  = "Calibration Wizard"
        case history      = "Measurement History"
        
        var id: Self { self }
        
        var body: some View {
            switch self {
            case .liveAnalyzer: return FFTAnalyzerView()
            case .calibration: return CalibrationWizardView()
            case .history: return MeasurementHistoryView()
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch measurementTab {
                case .liveAnalyzer:
                    FFTAnalyzerView()
                case .calibration:
                    CalibrationWizardView()
                case .history:
                    MeasurementHistoryView()
                }
            }
            .navigationTitle("Messungen")
            .toolbar {
                TabPicker("Tab", selection: $measurementTab) {
                    ForEach(MeasurementTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                Spacer()
                Button(systemName: "gear") { /* Open settings */ }
            }
        }
    }
}

struct MeasurementHistoryView: View {
    @State private var pastMeasurements: [MeasurementRecord] = []
    
    var body: some View {
        List(pastMeasurements) { record in
            HStack {
                VStack(alignment: .leading) {
                    Text(record.name).font(.headline)
                    Text(record.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(String(format: "%.1f dB RMS", record.rmsLevel))
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Messungshistorie")
        .toolbar {
            Button("+ Neuen Eintrag") { addDummyMeasurement() }
        }
    }
    
    struct MeasurementRecord: Identifiable {
        let id = UUID()
        let name: String
        let date: Date
        let rmsLevel: Double
    }
    
    private func addDummyMeasurement() {
        // Implementation to add real recording
    }
}

// End of MeasurementsView.swift