// DXO24Controller/Models/EQBand.swift
//
// Parametric EQ band model shared across Views, ViewModels, and Services.

import Foundation

/// A single parametric EQ band of the DXO-24.
struct EQBand: Codable, Equatable, Identifiable {
    var id: UUID
    var frequency: Double   // 20.0 ... 20 000.0 Hz
    var gain: Double        // -15.0 ... +15.0 dB
    var qFactor: Double     // 0.1 ... 10.0
    var enabled: Bool       // default true

    // MARK: - Init

    init(id: UUID = UUID(),
         frequency: Double = 1000.0,
         gain:     Double = 0.0,
         qFactor:  Double = 1.414,
         enabled:  Bool   = true) {
        self.id        = id
        self.frequency = frequency
        self.gain      = gain
        self.qFactor   = qFactor
        self.enabled   = enabled
    }

    enum ValidationError: String, Error {
        case frequencyOutOfRange  = "Frequency must be 20 ... 20 000 Hz"
        case gainOutOfRange       = "Gain must be -15 ... +15 dB"
        case qFactorOutOfRange    = "Q factor must be 0.1 ... 10.0"
    }

    func validate() throws {
        guard (20.0 ... 20_000.0).contains(frequency) else { throw ValidationError.frequencyOutOfRange }
        guard (-15.0 ... 15.0).contains(gain)         else { throw ValidationError.gainOutOfRange }
        guard (0.1 ... 10.0).contains(qFactor)        else { throw ValidationError.qFactorOutOfRange }
    }

    // MARK: - Presets

    static var flatPreset: [EQBand] {
        [
            EQBand(frequency: 31.5,   gain: 0, qFactor: 1.0, enabled: true),
            EQBand(frequency: 100.0,  gain: 0, qFactor: 1.0, enabled: true),
            EQBand(frequency: 1000.0, gain: 0, qFactor: 1.0, enabled: true),
            EQBand(frequency: 4000.0, gain: 0, qFactor: 1.0, enabled: true),
            EQBand(frequency: 16_000.0, gain: 0, qFactor: 1.0, enabled: true),
        ]
    }
}
