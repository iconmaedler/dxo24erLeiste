// DXO24Controller/Views/FrequencyResponseView.swift
//
// Live frequency response chart backed by SwiftUI Charts (macOS 13+).
// Falls back to system placeholder detail text when Charts import fails.

#if canImport(Charts)
import Charts
#endif
import SwiftUI

struct FrequencyResponseView: View {
    @State private var showTarget: Bool = true
    @State private var showEQ: Bool = true
    @EnvironmentObject private var viewModel: DeviceViewModel

    private var eqCurve: [DataPoint] {
        viewModel.device.eqBands.enumerated().flatMap { idx, band in
            guard band.enabled else { return [] }
            let centerMag = band.gain
            let bandwidth = band.frequency / band.qFactor
            let fLow = max(20, band.frequency - bandwidth)
            let fHigh = min(20_000, band.frequency + bandwidth)
            return [
                .init(x: fLow,   y: 0),
                .init(x: band.frequency, y: centerMag),
                .init(x: fHigh,  y: 0),
            ]
        }
    }

    var body: some View {
        #if canImport(Charts)
        VStack(alignment: .leading) {
            HStack {
                Toggle("Show target curve (-3 dB soft target)", isOn: $showTarget)
                Toggle("Show EQ curve", isOn: $showEQ)
                Spacer()
            }
            .padding(.horizontal)

            Chart {
                ForEach(eqCurve) { point in
                    if showEQ {
                        LineMark(
                            x: .value("Frequency (Hz)", point.x, scale: .log),
                            y: .value("Magnitude (dB)", point.y)
                        )
                        .foregroundStyle(.tint)
                        .interpolationMethod(.catmullRom)
                    }
                    if showTarget {
                        RuleMark(y: .value("Soft target", -3))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .lineStyle(.init(dash: [4, 4]))
                    }
                }
            }
            .chartXScale(domain: 20...20_000)
            .chartXAxis {
                AxisMarks(
                    values: .stride(by: 100, from: 20, through: 20_000, by: 100)
                        .map { .log($0) }
                ) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel("")
                }
            }
            .chartYAxis {
                AxisMarks(values: .stride(by: 6, from: -12, through: 12)) { _ in
                    AxisGridLine()
                    AxisValueLabel("dB")
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Frequency Response")
        #else
        VStack(alignment: .leading) {
            HStack {
                Toggle("Show target curve", isOn: $showTarget)
                Toggle("Show EQ", isOn: $showEQ)
                Spacer()
            }
            .padding(.horizontal)
            Text("SwiftUI Charts unavailable on this build. Wire the backend curve on macOS 14+.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Frequency Response")
        #endif
    }

    private struct DataPoint: Identifiable {
        let id = UUID()
        let x: Double
        let y: Double
    }
}
