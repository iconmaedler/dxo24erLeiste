// DXO24Controller/Views/CalibrationView.swift
//
// Guided room calibration with automatic calculation and EQ suggestions.

import SwiftUI

struct CalibrationView: View {
    @State private var room: RoomParameters = .init()
    @State private var resultText: String = ""
    @State private var suggestedEQ: [EQBand] = []
    @EnvironmentObject private var viewModel: DeviceViewModel

    var body: some View {
        Form {
            Section("Room dimensions") {
                HStack {
                    Text("Width (m):")
                    TextField("Width", value: $room.width, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                HStack {
                    Text("Depth (m):")
                    TextField("Depth", value: $room.depth, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                HStack {
                    Text("Height (m):")
                    TextField("Height", value: $room.height, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
            }

            Section("Surface & placement") {
                Picker("Surface", selection: $room.surface) {
                    ForEach(RoomParameters.Surface.allCases, id: \.self) { Text($0.localizedName).tag($0) }
                }
                Picker("Placement", selection: $room.speakerPlacement) {
                    ForEach(RoomParameters.Placement.allCases, id: \.self) { Text($0.localizedName).tag($0) }
                }
                HStack {
                    Text("Listening distance (m):")
                    TextField("Distance", value: $room.listeningDistance, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                Toggle("Subwoofer enabled", isOn: $room.subwooferEnabled)
            }

            Section("Calculations") {
                Button("Calculate room modes + RT60") {
                    runCalculation()
                }
                if !resultText.isEmpty {
                    Text(resultText).font(.caption).foregroundStyle(.secondary)
                }
            }

            if !suggestedEQ.isEmpty {
                Section("Suggested EQ correction") {
                    ForEach(suggestedEQ.indices, id: \.self) { idx in
                        let band = suggestedEQ[idx]
                        HStack {
                            Text("\(Int(band.frequency)) Hz")
                            Spacer()
                            Text("\(String(format: "%.1f", band.gain)) dB")
                            Spacer()
                            Text("Q \(String(format: "%.1f", band.qFactor))")
                            Spacer()
                            Button("Apply") {
                                var updated = viewModel.device
                                guard idx < updated.eqBands.count else { return }
                                updated.eqBands[idx] = band
                                viewModel.device = updated
                                Task { await viewModel.sendEQBand(at: idx) }
                            }
                            .buttonStyle(.borderedProminent)
                            .font(.caption)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func runCalculation() {
        let modes = CalculationService.calculateRoomModes(
            width: room.width, depth: room.depth, height: room.height
        )
        let rt60 = CalculationService.calculateRT60(
            width: room.width, depth: room.depth, height: room.height, surface: room.surface
        )
        let preview = modes
            .prefix(8)
            .map { "\(String(format: "%.1f", $0.frequency)) Hz" }
            .joined(separator: ", ")
        resultText = "RT60: \(String(format: "%.2f", rt60)) s | Top modes: \(preview) ..."

        let correction = CalculationService.generateEQCorrection(roomModes: modes)
        suggestedEQ = correction
    }
}
