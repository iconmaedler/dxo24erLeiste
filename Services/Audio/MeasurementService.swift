// DXO24Controller/Services/Audio/MeasurementService.swift
//
// High-level measurement coordinator.
// Delegates to MeasurementEngine which performs a real AVAudioEngine sweep + FFT.
//
import AVFoundation

enum MeasurementService {
    static let defaultSampleRate: Double = MeasurementEngine.defaultSampleRate
    static let defaultFFTSize: Int = MeasurementEngine.defaultFFTSize

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

    /// Requests microphone permission. On macOS, the system prompts automatically once
    /// the first AVAudioEngine input tap is installed; this method is a no-op shim.
    static func requestMicrophonePermission() async -> Bool {
        // No explicit API on macOS.  The TCC prompt fires on first input tap.
        true
    }

    /// Runs a calibration sweep and returns an array of (frequency, magnitude) tuples.
    static func startCalibrationSweep(duration: TimeInterval = 15.0) async throws -> [(frequency: Double, magnitude: Double)] {
        let bins = try await MeasurementEngine.measureRoomResponse(duration: duration)
        return bins.map { ($0.frequency, $0.magnitude) }
    }
}

// End of MeasurementService.swift
