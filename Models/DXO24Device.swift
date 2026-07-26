// DXO24Controller/Models/DXO24Device.swift
//
// Core device state model for the Omnitronic DXO-24.
// All values are validated at init time and clamp to hardware-accurate ranges.

import Foundation

/// Represents the complete parameter set of the DXO-24 device.
struct DXO24Device: Codable, Equatable {
    var inputLevel: Double        // -60.0 ... +12.0 dB
    var outputLevel: Double       // -60.0 ... +12.0 dB
    var inputMute: Bool
    var outputMute: Bool
    var crossoverFrequency: Double // 20.0 ... 300.0 Hz
    var crossoverSlope: Int       // 12 | 24 | 48 dB/oct
    var polarity: Bool           // false = normal, true = inverted
    var phaseDelay: Double       // 0.0 ... 20.0 ms
    var limiterThreshold: Double // -20.0 ... +12.0 dB
    var eqBands: [EQBand]
    var presetName: String

    // MARK: - Validation

    enum ValidationError: String, Error {
        case inputLevelOutOfRange      = "Input level out of range (-60 ... +12 dB)"
        case outputLevelOutOfRange     = "Output level out of range (-60 ... +12 dB)"
        case crossoverFreqOutOfRange   = "Crossover frequency out of range (20 ... 300 Hz)"
        case crossoverSlopeInvalid     = "Crossover slope must be 12, 24, or 48 dB/oct"
        case phaseDelayOutOfRange      = "Phase delay out of range (0 ... 20 ms)"
        case limiterThresholdOutOfRange = "Limiter threshold out of range (-20 ... +12 dB)"
    }

    init(inputLevel: Double     = -6.0,
         outputLevel: Double    =  0.0,
         inputMute: Bool        = false,
         outputMute: Bool       = false,
         crossoverFrequency: Double = 80.0,
         crossoverSlope: Int    = 24,
         polarity: Bool         = false,
         phaseDelay: Double     =  0.0,
         limiterThreshold: Double = 0.0,
         eqBands: [EQBand]?    = nil,
         presetName: String     = "Flat") throws {

        self.inputLevel       = inputLevel
        self.outputLevel      = outputLevel
        self.inputMute        = inputMute
        self.outputMute       = outputMute
        self.crossoverFrequency = crossoverFrequency
        self.crossoverSlope   = crossoverSlope
        self.polarity         = polarity
        self.phaseDelay       = phaseDelay
        self.limiterThreshold = limiterThreshold
        self.eqBands          = eqBands ?? EQBand.flatPreset
        self.presetName       = presetName

        try validate()
    }

    init() throws {
        try self.init(eqBands: EQBand.flatPreset)
    }

    mutating func validate() throws {
        guard (-60.0 ... 12.0).contains(inputLevel)   else { throw ValidationError.inputLevelOutOfRange }
        guard (-60.0 ... 12.0).contains(outputLevel)  else { throw ValidationError.outputLevelOutOfRange }
        guard (20.0 ... 300.0).contains(crossoverFrequency) else { throw ValidationError.crossoverFreqOutOfRange }
        guard [12, 24, 48].contains(crossoverSlope)   else { throw ValidationError.crossoverSlopeInvalid }
        guard (0.0 ... 20.0).contains(phaseDelay)     else { throw ValidationError.phaseDelayOutOfRange }
        guard (-20.0 ... 12.0).contains(limiterThreshold) else { throw ValidationError.limiterThresholdOutOfRange }
        for band in eqBands { try band.validate() }
    }

    // MARK: - Convenience

    static var flatPreset: DXO24Device {
        try! DXO24Device(eqBands: EQBand.flatPreset, presetName: "Flat")
    }
}
