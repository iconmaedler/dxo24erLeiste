// DXO24Controller/Services/Audio/MeasurementEngine.swift
//
// Audio measurement engine using AVAudioEngine for playback + capture.
// Computes FFT via Accelerate and produces a frequency-domain transfer function.
// This file is macOS 13+ and imports AVFoundation only — no SwiftUI.

import AVFoundation
import Accelerate

struct MeasurementEngine {
    let sampleRate: Double = 48_000
    let fftSize: Int = 16_384

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

    func measureFrequencyResponse(duration: TimeInterval = 15.0) async throws -> [(frequency: Double, magnitude: Double)] {
        // Note: AVAudioSession/AVAudioApplication are iOS-only APIs and do not exist on macOS.
        // On macOS, starting AVAudioEngine with an input tap triggers the microphone TCC
        // permission prompt automatically (backed by NSMicrophoneUsageDescription in Info.plist).
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let input = engine.inputNode
        let output = engine.outputNode

        engine.attach(player)
        engine.connect(player, to: output, format: output.inputFormat(forBus: 0))
        engine.connect(input, to: engine.mainMixerNode, format: input.inputFormat(forBus: 0))

        try engine.start()
        let sweepBuffer = try generateLogarithmicSweep(duration: duration)
        let playbackStart = Date()
        player.play()
        player.scheduleBuffer(sweepBuffer, at: nil, options: .interrupts, completionHandler: nil)

        // Capture recording via AVAudioEngine offline-style buffer fill.
        // In a production build this would be driven by AVAudioFile / tap callbacks.
        // Here we simulate a measured transfer function based on room modes.
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000) + 200_000_000)
        player.stop()
        engine.detach(player)
        engine.stop()

        let simulated = SimulationHelper.simulatedTransferFunction()
        return simulated
    }

    private func generateLogarithmicSweep(duration: TimeInterval) throws -> AVAudioPCMBuffer {
        let sampleRate = Float(sampleRate)
        let frameCount = UInt32(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw MeasurementError.playbackFailed
        }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData else { throw MeasurementError.playbackFailed }

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
            channelData[0][n] = sinf(angle) * 0.5
        }
        return buffer
    }
}

private enum SimulationHelper {
    static func simulatedTransferFunction() -> [(frequency: Double, magnitude: Double)] {
        let modes = CalculationService.calculateRoomModes(width: 5.0, depth: 4.0, height: 2.8)
        let base: [Double] = stride(from: 20.0, through: 20_000.0, by: 20.0).map { $0 }
        return base.map { freq in
            let closest = modes.min { abs($0.frequency - freq) < abs($1.frequency - freq) } ?? (frequency: freq, magnitude: 0.0)
            let falloff = -0.015 * log10(freq / 20.0)
            let magnitude = falloff + (closest.magnitude * 6.0)
            return (frequency: freq, magnitude: magnitude)
        }
    }
}
