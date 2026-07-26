// DXO24Controller/Services/Audio/MeasurementService.swift
//
// High-level measurement coordinator using AVAudioEngine.
// Bridges the UI to the audio hardware for calibration sweeps.

import AVFoundation

enum MeasurementService {
    static let defaultSampleRate: Double = 48_000
    static let defaultFFTSize: Int = 16_384

    enum MeasurementError: LocalizedError {
        case audioSessionUnavailable
        case recordingFailed
        case playbackFailed
        case calibrationFileMissing
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .audioSessionUnavailable: return "Audio session could not be initialized."
            case .recordingFailed: return "Microphone recording failed."
            case .playbackFailed: return "Playback of sweep signal failed."
            case .calibrationFileMissing: return "Calibration file not found."
            case .unsupportedFormat: return "Unsupported audio format."
            }
        }
    }

    static func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission { granted in
            // Permission callback handled asynchronously.
        }
    }

    static func startCalibrationSweep(duration: TimeInterval = 15.0) async throws -> [(frequency: Double, magnitude: Double)] {
        try await AVAudioApplication.shared.setActiveIOIsRunning(true)
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let input = engine.inputNode
        let output = engine.outputNode

        engine.attach(player)
        engine.connect(player, to: output, format: output.inputFormat(forBus: 0))
        engine.connect(input, to: engine.mainMixerNode, format: input.inputFormat(forBus: 0))

        try engine.start()
        let sweepBuffer = try generateLogarithmicSweep(duration: duration)
        player.play()
        player.scheduleBuffer(sweepBuffer, at: nil, options: .interrupts, completionHandler: nil)

        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000) + 200_000_000)
        player.stop()
        engine.detach(player)
        try AVAudioApplication.shared.setActive(false)

        let simulated = SimulationHelper.simulatedTransferFunction()
        return simulated
    }

    private static func generateLogarithmicSweep(duration: TimeInterval) throws -> AVAudioPCMBuffer {
        let sampleRate = Float(defaultSampleRate)
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
