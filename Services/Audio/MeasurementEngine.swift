// DXO24Controller/Services/Audio/MeasurementEngine.swift
//
// Real audio measurement engine using AVAudioEngine.
// Plays a logarithmic sweep, captures the microphone response via an input tap,
// and computes the FFT magnitude spectrum with Accelerate/vDSP.
//
import AVFoundation
import Accelerate
import os

struct MeasurementEngine {
    static let defaultSampleRate: Double = 48_000
    static let defaultFFTSize: Int = 16_384

    struct FrequencyBin {
        let frequency: Double  // Hz
        let magnitude: Double  // dB
    }

    enum MeasurementError: LocalizedError {
        case audioSessionUnavailable
        case recordingFailed
        case playbackFailed

        var errorDescription: String? {
            switch self {
            case .audioSessionUnavailable: return "Audio session could not be initialized."
            case .recordingFailed:         return "Microphone recording failed."
            case .playbackFailed:          return "Playback of sweep signal failed."
            }
        }
    }

    /// Runs a logarithmic sweep for `duration` seconds, captures the response, and returns the FFT bins.
    static func measureRoomResponse(duration: TimeInterval = 15.0) async throws -> [FrequencyBin] {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let inputNode = engine.inputNode
        let outputNode = engine.outputNode

        // Attach and connect player -> output
        engine.attach(player)
        engine.connect(player, to: outputNode, format: outputNode.inputFormat(forBus: 0))

        // Capture buffer for input tap
        let capture = SampleCaptureBuffer()
        let inputFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0,
                              bufferSize: AVAudioFrameCount(defaultFFTSize),
                              format: inputFormat) { buffer, _ in
            capture.append(buffer: buffer)
        }

        // Start engine
        try engine.start()

        // Generate and play sweep
        let sweepBuffer = try generateLogarithmicSweep(duration: duration)
        player.play()
        player.scheduleBuffer(sweepBuffer, at: nil, options: .interrupts, completionHandler: nil)

        // Wait for sweep + settle
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000) + 500_000_000)

        player.stop()
        engine.stop()
        inputNode.removeTap(onBus: 0)

        let samples = capture.flush()
        guard samples.count >= defaultFFTSize else {
            throw MeasurementError.recordingFailed
        }

        // FFT on the first window centered around the sweep response.
        let windowStart = max(0, (samples.count - defaultFFTSize) / 2)
        let windowSlice = Array(samples[windowStart..<(windowStart + defaultFFTSize)])
        let magnitudes = try performRealFFT(on: windowSlice)

        // Map bins to frequencies
        var result: [FrequencyBin] = []
        let binCount = magnitudes.count
        let freqResolution = defaultSampleRate / Double(binCount)
        for (i, mag) in magnitudes.enumerated() {
            let freq = Double(i) * freqResolution
            let db = 20.0 * log10(max(Double(mag), 1e-12))
            result.append(FrequencyBin(frequency: freq, magnitude: db))
        }
        return result
    }

    // MARK: - Sweep generator (logarithmic 20 Hz -> 20 kHz)

    private static func generateLogarithmicSweep(duration: TimeInterval) throws -> AVAudioPCMBuffer {
        let sampleRate = Float(defaultSampleRate)
        let frameCount = UInt32(duration * Double(sampleRate))
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw MeasurementError.playbackFailed
        }
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData?.pointee else {
            throw MeasurementError.playbackFailed
        }
        let channels = UnsafeMutableBufferPointer(start: channelData, count: Int(frameCount))

        let sweepStart: Float = 20.0
        let sweepEnd: Float = 20_000.0
        let logStart = log2f(sweepStart)
        let logEnd = log2f(sweepEnd)
        let logRange = logEnd - logStart

        for n in 0 ..< Int(frameCount) {
            let t = Float(n) / Float(frameCount)
            let logF = logStart + t * logRange
            let f = powf(2.0, logF)
            let angle = 2.0 * .pi * f * (Float(n) / sampleRate)
            channels[n] = sinf(angle) * 0.5
        }
        return buffer
    }

    // MARK: - Real FFT (vDSP)

    private static func performRealFFT(on samples: [Float]) throws -> [Float] {
        let n = samples.count
        guard n > 0, (n & (n - 1)) == 0 else {
            throw MeasurementError.playbackFailed // must be power of two
        }
        let log2n = vDSP_Length(log2(Float(n)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            throw MeasurementError.playbackFailed
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var real = samples
        var imag = [Float](repeating: 0, count: n)
        var split = DSPSplitComplex(realp: &real, imagp: &imag)

        vDSP_fft_zip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

        var magnitudes = [Float](repeating: 0, count: n / 2)
        vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(magnitudes.count))

        var amplitudes = [Float](repeating: 0, count: magnitudes.count)
        vDSP_vsqrt(magnitudes, 1, &amplitudes, 1, vDSP_Length(amplitudes.count))
        return amplitudes
    }
}

// MARK: - Thread-safe capture buffer

private final class SampleCaptureBuffer: @unchecked Sendable {
    private var samples: [Float] = []
    private let lock = NSLock()

    func append(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channel = channelData[0]
        let count = Int(buffer.frameLength)
        let pointer = UnsafeBufferPointer(start: channel, count: count)
        lock.lock()
        samples.append(contentsOf: pointer)
        lock.unlock()
    }

    func flush() -> [Float] {
        lock.lock()
        let result = samples
        samples.removeAll(keepingCapacity: false)
        lock.unlock()
        return result
    }
}

// End of MeasurementEngine.swift
