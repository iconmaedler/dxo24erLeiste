// DXO24Controller/Views/CalibrationWizardView.swift
//
// Guided Calibration Assistant with intelligent room detection and automatic EQ suggestions.
//
import SwiftUI
import Combine

struct CalibrationWizardView: View {
    @EnvironmentObject private var viewModel: DeviceViewModel
    
    // Wizard state
    @State private var step = 1
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var progressText: String = ""
    
    @State private var roomName = ""
    @State private var roomWidth: Double = 5.0
    @State private var roomDepth: Double = 4.0
    @State private var roomHeight: Double = 2.8
    
    // Results after completion
    @State private var showRecommendations = false
    @State private var suggestedBands: [EQBand] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress Indicator
            ProgressView(value: Float(step), total: Float(5))
                .progressStyle(.linear)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Step \(step)/5 - getStepTitle())
                    .font(.headline)
                if step == 1 { getStepContent1() }
                else if step == 2 { getStepContent2() }
                else if step == 3 { getStepContent3() }
                else if step == 4 { getStepContent4() }
                else if step == 5 { getStepContent5() }
            }
            
            Spacer()
            
            if let msg = errorMessage {
                Text(msg)
                    .foregroundColor(.red)
                    .padding()
            }
            
            if !progressText.isEmpty {
                Text(progressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Navigation Buttons
            HStack {
                if step > 1 {
                    Button("Previous") { previousStep() }
                        .buttonStyle(.bordered)
                }
                Spacer()
                if step < 5 {
                    Button("Next") { nextStep() }
                        .buttonStyle(.borderedProminent)
                } else if step == 5 && showRecommendations {
                    Button("Finish") { finishWizard() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Spacer()
                }
            }
        }
        .padding()
        .navigationTitle("Calibration Wizard")
        .onAppear { startWizard() }
    }
    
    // MARK: - Wizard Steps
    
    private func getStepTitle() -> String {
        switch step {
        case 1: return "Room Setup"
        case 2: return "Microphone Placement"
        case 3: return "Speaker Configuration"
        case 4: return "Start Measurement"
        case 5: return "Review Results"
        default: return "Setup"
        }
    }
    
    private func getStepContent1() -> some View {
        Form {
            Section("Room Dimensions") {
                TextField("Room Name", text: $roomName)
                HStack {
                    Text("Width (m):")
                    TextField("", value: $roomWidth, formatter: NumberFormatter())
                }
                HStack {
                    Text("Depth (m):")
                    TextField("", value: $roomDepth, formatter: NumberFormatter())
                }
                HStack {
                    Text("Height (m):")
                    TextField("", value: $roomHeight, formatter: NumberFormatter())
                }
            }
        }
    }
    
    private func getStepContent2() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Position your microphone at the primary listening position.")
            Text("Recommended:")
                .font(.subheadline)
            List {
                HStack { Image(systemName: "checkmark"); Text("Ear level when seated") }
                HStack { Image(systemName: "checkmark"); Text("Distance from walls ≥ 1 meter") }
                HStack { Image(systemName: "checkmark"); Text("Clear line of sight to speakers") }
            }
        }
    }
    
    private func getStepContent3() -> some View {
        Form {
            Section("Speaker Configuration") {
                Picker("Number of Speakers", selection: $viewModel.device.numSpeakers) {
                    ForEach(1...8, id: \.self) { n in
                        Text("\(n) speaker\(n > 1 ? "s" : "")")
                            .tag(n)
                    }
                }
                
                Picker("Subwoofer Status", selection: $viewModel.device.subwooferEnabled) {
                    Text("Enabled").tag(true)
                    Text("Disabled").tag(false)
                }
            }
        }
    }
    
    private func getStepContent4() -> some View {
        VStack(spacing: 16) {
            Text("Ready to calibrate? This will play a sweep tone through all speakers.")
            
            Button("Start Measurement") {
                startMeasurement()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
            
            if isRunning {
                ProgressView("Measuring...", nil)
                    .progressStyle(.spinner)
            }
        }
    }
    
    private func getStepContent5() -> some View {
        VStack(spacing: 16) {
            if !suggestedBands.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested EQ Adjustments:")
                        .font(.headline)
                    
                    List(suggestedBinds.indices, id: \.self) { idx in
                        let band = suggestedBands[idx]
                        HStack {
                            Text("Band \(idx + 1):")
                            Text(String(format: "%.0f Hz", band.frequency))
                            Spacer()
                            Text(String(format: "+%.1f dB", band.gain))
                                .foregroundColor(band.gain > 0 ? .green : .red)
                        }
                    }
                }
                
                Button("Apply Suggested EQ") {
                    applySuggestedEQ()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("No recommendations available at this time.")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Wizard Logic
    
    private func startWizard() {
        setupRoomFromPlanner()
    }
    
    private func setupRoomFromPlanner() {
        // Get room parameters from the planner snapshot if available
        if let room = viewModel.roomPlannerSnapshot {
            roomWidth = room.width
            roomDepth = room.depth
            roomHeight = room.height
            roomName = "Planned Room"
        }
        nextStep()
    }
    
    private func nextStep() {
        guard step < 5 else { return }
        step += 1
        progressText = "Step \(step) of 5"
        
        if step == 5 {
            performAnalysis()
        }
    }
    
    private func previousStep() {
        guard step > 1 else { return }
        step -= 1
        progressText = ""
    }
    
    private func startMeasurement() {
        isRunning = true
        progressText = "Playing sweep and recording..."
        
        Task {
            do {
                // Start actual measurement
                let bins = try await MeasurementService.startCalibrationSweep(duration: 15.0)
                progressText = "Processing response data..."
                
                await MainActor.run {
                    // Store measured data
                    viewModel.measuredResponse = bins
                    step = 5
                    isRunning = false
                    performAnalysis(bins: bins)
                }
            } catch {
                errorMessage = "Measurement failed: \(error.localizedDescription)"
                isRunning = false
            }
        }
    }
    
    private func performAnalysis(bins: [FrequencyBin]? = nil) {
        progressText = "Analyzing frequency response..."
        
        Task {
            await MainActor.run {
                let analysisBins = bins ?? (viewModel.measuredResponse ?? [])
                suggestedBands = AnalysisEngine.generateRecommendations(for: analysisBins, device: viewModel.device)
                showRecommendations = true
                progressText = "Complete!"
            }
        }
    }
    
    private func applySuggestedEQ() {
        var updatedDevice = viewModel.device
        updatedDevice.eqBands = suggestedBands
        
        // Update UI with new EQ values
        Task {
            viewModel.device = updatedDevice
            viewModel.updateHeadroomWarning()
            // After applying, send to device if connected
            if viewModel.isConnected {
                for i in 0..<updatedDevice.eqBands.count {
                    await viewModel.sendEQBand(at: i)
                }
            }
        }
        
        finishWizard()
    }
    
    private func finishWizard() {
        // Reset wizard state
        step = 1
        showRecommendations = false
        progressText = ""
        errorMessage = nil
    }
}

// MARK: - Analysis Engine - Generate EQ Recommendations

final class AnalysisEngine {
    static func generateRecommendations(for measurements: [FrequencyBin], device: DXO24Device) -> [EQBand] {
        // Simple greedy algorithm to create EQ bands that match target curve (soft target curve centered around -3dB)
        var recommendations: [EQBand] = []
        let targetCurveSoftTarget: (Double) -> Double = { _ in -3.0 } // Soft target reference
        
        // Find significant deviations from target
        var peaks: [(freq: Double, magnitude: Double)] = []
        
        for bin in measurements {
            let deviation = bin.magnitude - targetCurveSoftTarget(bin.frequency)
            // Only consider significant deviations (>3dB difference)
            if abs(deviation) > 3.0 {
                peaks.append((bin.frequency, deviation))
            }
        }
        
        // Sort peaks by magnitude of deviation
        peaks.sort { abs($0.magnitude) > abs($1.magnitude) }
        
        // Create up to 5 EQ bands (based on expertise level limit)
        let maxBands = min(5, peaks.count)
        for i in 0..<maxBands {
            let peak = peaks[i]
            // Determine if it's a peak or dip
            let gain: Double
            if peak.magnitude > 0 {
                // Need to cut (negative gain)
                gain = min(-1.5, peak.magnitude * -0.5) // Cut half of excess, max 1.5dB
            } else {
                // Need to boost (positive gain)
                gain = min(1.5, peak.magnitude * 0.5) // Boost half of deficit, max 1.5dB
            }
            
            // Auto-Q based on bandwidth needed
            let qFactor: Double = peak.magnitude > 10 ? 0.7 : 1.5 // Broader for large corrections
            
            recommendations.append(EQBand(
                frequency: peak.frequency,
                gain: gain,
                qFactor: qFactor,
                enabled: true
            ))
        }
        
        return recommendations
    }
}

// End of CalibrationWizardView.swift