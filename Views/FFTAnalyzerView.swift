// DXO24Controller/Views/FFTAnalyzerView.swift
//
// Echtzeit FFT-Anzeige mit Live-Frequenzanalyse während Messung oder Playback.
// Verwendet Accelerate Framework für schnelle FFT-Berechnung.
//

import SwiftUI
import Charts
import Accelerate

struct FFTAnalyzerView: View {
    @EnvironmentObject private var viewModel: DeviceViewModel
    
    // Measurement state
    @State private var isStreaming: Bool = false
    @State private var frequencyBins: [FrequencyBin] = []
    @State private var sampleCount: Int = 0
    @State private var maxMagnitude: Double = 0.0
    
    private let fftSize: Int = 1024
    private var setupFFTSetup?: FFTSetup?
    private var inputReal: [Float] = [Float](repeating: 0, count: fftSize)
    private var outputImag: [Float] = [Float](repeating: 0, count: fftSize)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FFT Analyzer")
                    .font(.title2.bold())
                
                if isStreaming {
                    Button("Stop") { stopStreaming() }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                } else {
                    Button(isActiveMeasurement() ? "Continue" : "Start") { 
                        if isStreaming { continueStreaming() } 
                        else { startStreaming() } 
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
                Text("\(sampleCount) samples")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Max: \(String(format: "%.1f dB", maxMagnitude))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            if frequencyBins.isEmpty {
                VStack {
                    Image(systemName: "waveform.path.max.min")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text(isActiveMeasurement() ? "Messung in Progress..." : "Drücke Start, um Analyse zu beginnen")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(frequencyBins) { bin in
                    LineMark(
                        x: .value("Frequency (Hz)", bin.frequency, scale: .log),
                        y: .value("Magnitude (dB)", bin.magnitude)
                    )
                    .foregroundStyle(.tint)
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 20, from: 20, through: 20_000, by: 20)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel("")
                    }
                }
                .chartYAxis {
                    AxisMarks(values: stride(from: -60, through: 10, by: 10)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel("dB")
                    }
                }
                .frame(height: 300)
                .padding(.horizontal)
                
                HStack {
                    Slider(value: $fftSize / 1024, in: 0...7, step: 1) {
                        Text("FFT Size:")
                    }
                    Text("\(Int(pow(2, Double(fftSize)))) pts")
                        .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("FFT Analyzer")
        .onDisappear { stopStreaming() }
    }
    
    private func isActiveMeasurement() -> Bool {
        // Could check if audio engine is running
        return false
    }
    
    private func startStreaming() {
        isStreaming = true
        frequencyBins = []
        sampleCount = 0
        maxMagnitude = 0
        
        // Setup FFT
        guard let log2n = fftSize > 0 ? Int(log2(Double(fftSize))) else { return }
        setupFFTSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        
        // Start audio measurement from viewModel
        Task { await startAudioMeasurement() }
    }
    
    private func continueStreaming() {
        isStreaming = true
        Task { await continueAudioMeasurement() }
    }
    
    private func stopStreaming() {
        isStreaming = false
        if let setup = setupFFTSetup {
            vDSP_destroy_fftsetup(setup)
        }
        setupFFTSetup = nil
    }
    
    private func startAudioMeasurement() async {
        // Connect to audio engine tap, perform FFT on incoming buffers
        // This would integrate with MeasurementEngine
        await processIncomingAudio()
    }
    
    private func processIncomingAudio() async {
        guard isStreaming else { return }
        
        // In a real implementation, this would receive audio frames from AVAudioEngine tap
        // For now, simulate some data
        let simulatedData = generateSimulatedAudio()
        
        // Perform FFT
        performFFT(data: simulatedData)
        
        // Update UI
        await MainActor.run {
            sampleCount += fftSize
            if !frequencyBins.isEmpty {
                maxMagnitude = max(maxMagnitude, frequencyBins.last?.magnitude ?? 0)
            }
        }
        
        // Continue streaming
        if isStreaming {
            try? await Task.sleep(nanoseconds: 100_000_000) // ~100ms interval
            await processIncomingAudio()
        }
    }
    
    private func generateSimulatedAudio() -> [Float] {
        // Simulate audio input - in real app this comes from AVAudioEngine tap
        var audio = [Float](repeating: 0, count: fftSize)
        for i in 0..<fftSize {
            audio[i] = Float(sin(Double(i * 4 * .pi / Double(fftSize)))) * 0.5
        }
        return audio
    }
    
    private func performFFT(data: [Float]) {
        guard let setup = setupFFTSetup else { return }
        
        var real = data
        var imag = [Float](repeating: 0, count: fftSize)
        var split = DSPSplitComplex(realp: &real, imagp: &imag)
        
        vDSP_fft_zip(setup, &split, 1, vDSP_Length(log2(Float(fftSize))), FFTDirection(FFT_FORWARD))
        
        // Compute magnitudes
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(magnitudes.count))
        
        // Convert to bins
        var bins: [FrequencyBin] = []
        let freqResolution = 48000.0 / Double(fftSize)
        for i in 0..<magnitudes.count {
            let freq = Double(i) * freqResolution
            if freq >= 20 && freq <= 20_000 {
                let db = 20.0 * log10(max(Double(magnitudes[i]), 1e-12))
                bins.append(FrequencyBin(frequency: freq, magnitude: db))
            }
        }
        
        frequencyBins = bins
    }
}

extension FFTAnalyzerView {
    struct FrequencyBin: Identifiable {
        let id = UUID()
        let frequency: Double
        let magnitude: Double
    }
}

// End of FFTAnalyzerView.swift