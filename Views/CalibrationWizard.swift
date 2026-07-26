// DXO24Controller/Views/CalibrationWizard.swift
//
// Guided microphone calibration assistant with step-by-step UI.
// Covers placement, sweep simulation, and post-measurement EQ proposal.

import SwiftUI

enum CalibrationStep: Int, CaseIterable {
    case preparation = 0
    case placement
    case measurement
    case analysis
    case verification
}

struct CalibrationWizardView: View {
    @State private var step: CalibrationStep = .preparation
    @State private var room: RoomParameters = .init()
    @State private var measuredResponse: [(frequency: Double, magnitude: Double)] = []
    @State private var suggestedEQ: [EQBand] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Step", selection: $step) {
                        ForEach(CalibrationStep.allCases, id: \.self) { phase in
                            Text(phase.localizedName).tag(phase)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(step != .preparation)
                }

                switch step {
                case .preparation:
                    preparationView
                case .placement:
                    placementView
                case .measurement:
                    measurementView
                case .analysis:
                    analysisView
                case .verification:
                    verificationView
                }
            }
            .navigationTitle(step.localizedName)
            .toolbar {
                Button(step == .verification ? "Finish" : "Next") {
                    advanceStep()
                }
                .disabled(!canAdvance)
            }
        }
        .frame(width: 640, height: 520)
    }

    // MARK: - Steps

    private var preparationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Checklist")
                .font(.headline)
            Text("- Measurement microphone connected (UMIK-1 / ECM8000 / EMM-6 recommended)")
            Text("- Calibration file (.cal) loaded in Support folder")
            Text("- Quiet room, HVAC and fans off, doors/windows closed")
            Text("- DXO-24 connected and selected in the connection panel")
            Text("- Output level set to -12 dBFS to avoid clipping")
            Spacer()
        }
        .padding()
    }

    private var placementView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Place the microphone at the primary listening position.")
                .font(.headline)
            Text("Height: ear level (~1.1 m seated / ~1.6 m standing)")
            Text("Orientation: on-axis to the left or right speaker (0 degrees)")
            Text("Distance: 1.0 – 2.0 m from the speaker")
            Text("No obstructions between mic and speaker.")
            Spacer()
        }
        .padding()
    }

    private var measurementView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start a calibrated sine sweep (20 Hz – 20 kHz, 15 s) and capture the response.")
                .font(.headline)
            Button("Run simulated sweep") {
                runSimulatedSweep()
            }
            .buttonStyle(.borderedProminent)
            if !measuredResponse.isEmpty {
                Text("Sweep complete. Captured \(measuredResponse.count) data points.")
                    .foregroundStyle(.green)
            }
            Spacer()
        }
        .padding()
    }

    private var analysisView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis results")
                .font(.headline)
            if measuredResponse.isEmpty {
                Text("No measurement available. Return to Measurement step.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Detected modes:")
                ForEach(Array(measuredResponse.prefix(6)), id: \.frequency) { point in
                    Text("\(String(format: "%.1f", point.frequency)) Hz — \(String(format: "%.1f", point.magnitude)) dB")
                }
            }
            if !suggestedEQ.isEmpty {
                Divider()
                Text("Suggested EQ:")
                ForEach(suggestedEQ.indices, id: \.self) { idx in
                    let band = suggestedEQ[idx]
                    Text("\(idx + 1). \(Int(band.frequency)) Hz \(String(format: "%.1f", band.gain)) dB  Q\(String(format: "%.1f", band.qFactor))")
                }
            }
            Spacer()
        }
        .padding()
    }

    private var verificationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Re-run the sweep after applying corrections and compare the responses.")
                .font(.headline)
            Text("Target: ±3 dB deviation from 20 Hz – 20 kHz.")
            Text("If > 6 dB deviation remains:")
            Text("- Add bass trapping near detected modal peaks")
            Text("- Move listening position or rotate the speaker slightly")
            Text("- Do not exceed +6 dB of total EQ boost")
            Spacer()
        }
        .padding()
    }

    // MARK: - Logic

    private var canAdvance: Bool {
        switch step {
        case .preparation:  true
        case .placement:    true
        case .measurement:  !measuredResponse.isEmpty
        case .analysis:     !suggestedEQ.isEmpty
        case .verification: true
        }
    }

    private func advanceStep() {
        guard canAdvance else { return }
        switch step {
        case .measurement:
            suggestedEQ = CalculationService.generateEQCorrection(roomModes: measuredResponse)
            if suggestedEQ.isEmpty {
                suggestedEQ = EQBand.flatPreset
            }
        case .analysis:
            ()
        default:
            ()
        }
        step = CalibrationStep(rawValue: min(step.rawValue + 1, CalibrationStep.allCases.count - 1)) ?? step
    }

    private func runSimulatedSweep() {
        let modes = CalculationService.calculateRoomModes(
            width: room.width,
            depth: room.depth,
            height: room.height
        )
        measuredResponse = modes.map { ($0.frequency, $0.magnitude * 6.0) }
    }
}

private extension CalibrationStep {
    var localizedName: String {
        switch self {
        case .preparation:  return "Preparation"
        case .placement:    return "Microphone Placement"
        case .measurement:  return "Measurement"
        case .analysis:     return "Analysis"
        case .verification: return "Verification"
        }
    }
}
