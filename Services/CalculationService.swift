// DXO24Controller/Services/CalculationService.swift
//
// Pure acoustic math library for the Room Calibration wizard.
// No I/O, no SwiftUI, no device dependencies.

import Foundation

// MARK: - Constants

private let speedOfSound: Double = 343.0 // m/s at ~20C

// MARK: - Public API

/// Pure acoustic math library for the Room Calibration wizard.
enum CalculationService {

/// Computes axial room modal frequencies and relative magnitudes up to maxOrder.
/// Result is sorted ascending by frequency and deduplicated within 0.5 Hz.
static func calculateRoomModes(width: Double,
                               depth: Double,
                               height: Double,
                               maxOrder: Int = 4) -> [(frequency: Double, magnitude: Double)] {
    let w = width, d = depth, h = height
    guard w > 0 && d > 0 && h > 0 else { return [] }

    var modes: [(frequency: Double, magnitude: Double)] = []
    for nx in 0...maxOrder {
        for ny in 0...maxOrder {
            for nz in 0...maxOrder {
                guard !(nx == 0 && ny == 0 && nz == 0) else { continue }
                let num = Double(nx * nx) / (w * w)
                        + Double(ny * ny) / (d * d)
                        + Double(nz * nz) / (h * h)
                let frequency = (speedOfSound / 2.0) * sqrt(num)
                let denom = Double(nx * nx) * (1.0 / (w * w))
                          + Double(ny * ny) * (1.0 / (d * d))
                          + Double(nz * nz) * (1.0 / (h * h))
                let magnitude = denom > 0 ? min(1.0, 1.0 / denom) : 1.0
                modes.append((frequency: frequency, magnitude: magnitude))
            }
        }
    }

    // Sort ascending and deduplicate frequencies within 0.5 Hz, keeping the higher magnitude.
    modes.sort { $0.frequency < $1.frequency }
    var deduped: [(frequency: Double, magnitude: Double)] = []
    var lastFrequency: Double?
    for mode in modes {
        if let prev = lastFrequency, abs(mode.frequency - prev) <= 0.5 {
            deduped[deduped.count - 1].magnitude = max(deduped[deduped.count - 1].magnitude, mode.magnitude)
        } else {
            deduped.append(mode)
        }
        lastFrequency = mode.frequency
    }
    let limited = deduped.prefix(50)
    return limited.map { ($0.frequency, $0.magnitude) }
}

/// Sabine RT60 estimate for a shoebox room with a uniform surface absorption model.
static func calculateRT60(width: Double,
                          depth: Double,
                          height: Double,
                          surface: RoomParameters.Surface) -> Double {
    let volume = width * depth * height
    let totalSurface = 2.0 * (width * depth + width * height + depth * height)
    guard volume > 0 && totalSurface > 0 else { return 0.5 }
    let raw = 0.161 * volume / (surface.absorptionCoefficient * totalSurface)
    return min(max(raw, 0.05), 2.0)
}

/// Crossover recommendation in Hz derived from speaker database entry and placement.
static func recommendCrossover(speaker: SpeakerModel,
                               placement: RoomParameters.Placement) -> Double {
    let factor: Double
    switch placement {
    case .freeStanding: factor = 8.0
    case .wall:         factor = 10.0
    case .corner:       factor = 12.0
    }
    let raw = speaker.wooferSizeInches * factor
    let nearest5 = (raw / 5.0).rounded() * 5.0
    return min(max(nearest5, 20.0), 200.0)
}

/// Propagation delay in milliseconds for a given distance in meters.
static func calculatePhaseDelay(distanceMeters: Double) -> Double {
    let milliseconds = (distanceMeters / speedOfSound) * 1000.0
    return min(max(milliseconds, 0.0), 20.0)
}

/// Headroom sanity check for a summed EQ correction.
static func checkHeadroom(eqGainSum: Double,
                          amplifierHeadroom: Double) -> (ok: Bool, warning: String?) {
    let okay = eqGainSum <= amplifierHeadroom
    let warning: String? = eqGainSum > 6.0
        ? "Excessive EQ gain (\(String(format: "%.1f", eqGainSum)) dB) may cause clipping or distortion."
        : nil
    return (ok: okay, warning: warning)
}

/// Convert dominant room modes into corrective EQ bands.
/// - Returns up to 5 bands prioritizing the largest modal peaks above the mean.
static func generateEQCorrection(roomModes: [(frequency: Double, magnitude: Double)],
                                 maxCutPerBand: Double = -6.0) -> [EQBand] {
    guard !roomModes.isEmpty else {
        return EQBand.flatPreset
    }

    let meanMagnitude = roomModes.map(\.magnitude).reduce(0, +) / Double(roomModes.count)
    let peakCandidates = roomModes
        .filter { $0.magnitude - meanMagnitude > 4.0 }
        .sorted { ($0.magnitude - meanMagnitude) > ($1.magnitude - meanMagnitude) }
        .prefix(5)

    if peakCandidates.isEmpty {
        return [
            EQBand(frequency: 80,      gain: -3.0, qFactor: 1.2, enabled: true),
            EQBand(frequency: 12_000,  gain: -1.0, qFactor: 0.8, enabled: true),
            EQBand(frequency: 1_000,   gain:  0.0, qFactor: 1.0, enabled: false),
            EQBand(frequency: 3_000,   gain:  0.0, qFactor: 1.0, enabled: false),
            EQBand(frequency: 6_000,   gain:  0.0, qFactor: 1.0, enabled: false),
        ]
    }

    return peakCandidates.enumerated().map { _, mode in
        let rawGain = -(mode.magnitude - meanMagnitude) * 0.8
        let clamped = max(maxCutPerBand, (rawGain * 10.0).rounded() / 10.0) // round to 0.1 dB
        return EQBand(
            frequency: (mode.frequency * 1.0).rounded(),
            gain: clamped,
            qFactor: 2.0,
            enabled: true
        )
    }
}

// MARK: - Private helpers

private static func round(toNearest: Double, _ value: Double) -> Double {
    (value / toNearest).rounded() * toNearest
}

} // enum CalculationService
