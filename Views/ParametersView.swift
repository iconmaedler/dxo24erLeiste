// DXO24Controller/Views/ParametersView.swift
//
// Primary parameter control surface for level, crossover, EQ, and timing.
// Reads and writes through the shared DeviceViewModel.

import SwiftUI

struct ParametersView: View {
    let expertise: ExpertiseLevel
    @EnvironmentObject private var viewModel: DeviceViewModel

    private var device: DXO24Device {
        get { viewModel.device }
        set { viewModel.device = newValue }
    }

    var body: some View {
        Form {
            Section("Levels") {
                InfoCard(title: "Level", message: "Input and output trim in dB. Keep headroom below 0 dB to avoid clipping.")
                HStack {
                    Slider(value: Binding(
                        get: { device.inputLevel },
                        set: { 
                            device.inputLevel = $0 
                            Task { await viewModel.sendLevels() } 
                        }
                    ), in: -60...12, step: 0.5)
                    Text("In \(String(format: "%.1f", device.inputLevel)) dB")
                        .frame(width: 90, alignment: .trailing)
                }
                HStack {
                    Slider(value: Binding(
                        get: { device.outputLevel },
                        set: { 
                            device.outputLevel = $0 
                            Task { await viewModel.sendLevels() } 
                        }
                    ), in: -60...12, step: 0.5)
                    Text("Out \(String(format: "%.1f", device.outputLevel)) dB")
                        .frame(width: 90, alignment: .trailing)
                }
                Toggle("Mute Input", isOn: Binding(
                    get: { device.inputMute },
                    set: { 
                        device.inputMute = $0 
                        Task { await viewModel.sendMutes() } 
                    }
                ))
                Toggle("Mute Output", isOn: Binding(
                    get: { device.outputMute },
                    set: { 
                        device.outputMute = $0 
                        Task { await viewModel.sendMutes() } 
                    }
                ))
            }

            Section("Crossover") {
                InfoCard(title: "Crossover", message: "Low-pass filter frequency and slope for the output path.")
                HStack {
                    Slider(value: Binding(
                        get: { device.crossoverFrequency },
                        set: { 
                            device.crossoverFrequency = $0 
                            Task { await viewModel.sendCrossover() } 
                        }
                    ), in: 20...200, step: 1)
                    Text("\(String(format: "%.0f", device.crossoverFrequency)) Hz")
                        .frame(width: 70, alignment: .trailing)
                }
                Picker("Slope", selection: Binding(
                    get: { device.crossoverSlope },
                    set: { 
                        device.crossoverSlope = $0 
                        Task { await viewModel.sendCrossover() } 
                    }
                )) {
                    Text("12 dB/oct").tag(12)
                    Text("24 dB/oct").tag(24)
                    Text("48 dB/oct").tag(48)
                }
                .pickerStyle(.segmented)
            }

            if expertise.showsPhase {
                Section("Timing") {
                    InfoCard(title: "Timing", message: "Adjust phase alignment and polarity to integrate subs and mains.")
                    HStack {
                        Slider(value: Binding(
                            get: { device.phaseDelay },
                            set: { 
                                device.phaseDelay = $0 
                                Task { await viewModel.sendPhase() } 
                            }
                        ), in: 0...20, step: 0.1)
                        Text("\(String(format: "%.1f", device.phaseDelay)) ms")
                            .frame(width: 70, alignment: .trailing)
                    }
                    Toggle("Invert Polarity", isOn: Binding(
                        get: { device.polarity },
                        set: { 
                            device.polarity = $0 
                            Task { await viewModel.sendPolarity() } 
                        }
                    ))
                }
            }

            Section("Equalizer") {
                InfoCard(title: "EQ", message: "Five parametric bands. Cut narrow peaks surgically; boost broad shelves gently.")
                ForEach(device.eqBands.indices, id: \.self) { idx in
                    HStack {
                        Toggle("Band \(idx + 1)", isOn: Binding(
                            get: { device.eqBands[idx].enabled },
                            set: { 
                                device.eqBands[idx].enabled = $0 
                                Task { await viewModel.sendEQBand(at: idx) } 
                            }
                        ))
                        Spacer()
                        Text("\(Int(device.eqBands[idx].frequency)) Hz")
                            .frame(width: 80, alignment: .trailing)
                        Slider(value: Binding(
                            get: { device.eqBands[idx].frequency },
                            set: { 
                                device.eqBands[idx].frequency = $0 
                                Task { await viewModel.sendEQBand(at: idx) } 
                            }
                        ), in: 20...20_000, step: 1)
                            .frame(width: 200)
                        Text("\(String(format: "%.1f", device.eqBands[idx].gain)) dB")
                            .frame(width: 68, alignment: .trailing)
                        Slider(value: Binding(
                            get: { device.eqBands[idx].gain },
                            set: { 
                                device.eqBands[idx].gain = $0 
                                Task { await viewModel.sendEQBand(at: idx) } 
                            }
                        ), in: -15...15, step: 0.5)
                            .frame(width: 160)
                        Text("Q \(String(format: "%.2f", device.eqBands[idx].qFactor))")
                            .frame(width: 52, alignment: .trailing)
                        Slider(value: Binding(
                            get: { device.eqBands[idx].qFactor },
                            set: { 
                                device.eqBands[idx].qFactor = $0 
                                Task { await viewModel.sendEQBand(at: idx) } 
                            }
                        ), in: 0.1...10, step: 0.05)
                            .frame(width: 140)
                    }
                }
            }

            if expertise.showsRawValues {
                Section("Limiter") {
                    InfoCard(title: "Limiter", message: "Ceiling threshold that prevents digital clipping downstream.")
                    HStack {
                        Slider(value: Binding(
                            get: { device.limiterThreshold },
                            set: { 
                                device.limiterThreshold = $0 
                                Task { await viewModel.sendLimiter() } 
                            }
                        ), in: -20...12, step: 0.5)
                        Text("\(String(format: "%.1f", device.limiterThreshold)) dB")
                            .frame(width: 90, alignment: .trailing)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { viewModel.updateHeadroomWarning() }
    }
}

// End of ParametersView.swift