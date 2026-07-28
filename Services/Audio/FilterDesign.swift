// DXO24Controller/Services/Audio/FilterDesign.swift
//
// Audio Filter Design Toolkit basierend auf Robert Bristow-Johnsons "Audio EQ Cookbook".
// Implementiert alle wichtigen Filtertypen für parametrische EQ, Crossover und mehr.
//
// Referenz: https://www.musicdsp.org/files/Audio-EQ-Cookbook.txt
//
import Foundation

/// Parametrischer EQ Filtertyp
enum EQFilterType: String, CaseIterable, Codable {
    case peaking         = "Peaking"       // Standard Shelves Filter zur EQ-Korrektur
    case lowPass         = "Low Pass"      // Tiefpassfilter
    case highPass        = "High Pass"     // Hochpassfilter
    case lowShelf        = "Low Shelf"     // niedriger Shelf-Filter (Gain)
    case highShelf       = "High Shelf"    // hoher Shelf-Filter (Gain)
    case notch           = "Notch"         // Kerbfilter zur Unterdrückung einer Frequenz
    case bandPass        = "Band Pass"     // Bandpassfilter
    case allPass         = "All Pass"      // Phaser / Delay Filter
    
    var description: String {
        switch self {
        case .peaking: return "Parametrisches Peaking-Filter"
        case .lowPass: return "Tiefpass-Filter (-24dB/oct default)"
        case .highPass: return "Hochpass-Filter (-24dB/oct default)"
        case .lowShelf: return "Niedriger Shelf-Filter"
        case .highShelf: return "Hoher Shelf-Filter"
        case .notch: return "Kerbfilter (Bandsperrfilter)"
        case .bandPass: return "Bandpass-Filter"
        case .allPass: return "All-Pass-Filter (Phasenverschiebung)"
        }
    }
    
    /// Gibt die Default-Belastung (Slope) für diese Filterart zurück
    var defaultSlope: Int {
        switch self {
        case .lowPass, .highPass: return 24
        case .peaking, .lowShelf, .highShelf, .notch, .bandPass, .allPass: return 0
        }
    }
}

/// Biquad Filter Koeffizientenstruktur
struct BiquadCoefficients: Codable, Equatable {
    let a0: Double
    let a1: Double
    let a2: Double
    let b0: Double
    let b1: Double
    let b2: Double
    
    /// Wendet den Biquad-Filter auf ein Sample an
    func process(_ input: Double, previousInput1: Double, previousInput2: Double, 
                 previousOutput1: Double, previousOutput2: Double) -> Double {
        let output = (b0 * input + b1 * previousInput1 + b2 * previousInput2 - 
                     a1 * previousOutput1 - a2 * previousOutput2) / a0
        return output
    }
    
    /// Berechnet Filteroutput mit zwei vorherigen Inputs/Outputs Speicher状态
    struct State {
        var input1: Double = 0
        var input2: Double = 0
        var output1: Double = 0
        var output2: Double = 0
        
        mutating func filter(_ coeff: BiquadCoefficients, _ input: Double) -> Double {
            let output = coeff.process(input, input1, input2, output1, output2)
            input2 = output1
            output2 = output1
            output1 = output
            input1 = input
            return output
        }
    }
}

/// Filterdesigner - central class for all filter computations
final class FilterDesigner {
    
    // MARK: - Public API
    
    /// Erzeugt einen Filter basierend auf Parametern
    static func createFilter(type: EQFilterType, frequency: Double, Q: Double, 
                            gainDb: Double? = nil, sampleRate: Double = 48000) -> BiquadCoefficients? {
        let designer = FilterDesigner()
        switch type {
        case .peaking:
            return designer.peakingEQ(frequency: frequency, Q: Q, gainDb: gainDb ?? 0, sampleRate: sampleRate)
        case .lowPass:
            return designer.lowPass(order: getFilterOrderFromSlope(type.defaultSlope), frequency: frequency, Q: Q, sampleRate: sampleRate)
        case .highPass:
            return designer.highPass(order: getFilterOrderFromSlope(type.defaultSlope), frequency: frequency, Q: Q, sampleRate: sampleRate)
        case .lowShelf:
            return designer.lowShelf(gainDb: gainDb ?? 0, frequency: frequency, Q: Q, sampleRate: sampleRate)
        case .highShelf:
            return designer.highShelf(gainDb: gainDb ?? 0, frequency: frequency, Q: Q, sampleRate: sampleRate)
        case .notch:
            return designer.notch(frequency: frequency, Q: Q, sampleRate: sampleRate)
        case .bandPass:
            return designer.bandPass(type: .gain, frequency: frequency, Q: Q, sampleRate: sampleRate)
        case .allPass:
            return designer.allPass(frequency: frequency, Q: Q, sampleRate: sampleRate)
        }
    }
    
    /// Berechnete Minimum-Phase EQ aus Magnitude Response
    static func minimumPhase(for magnitudes: [Double]) -> [Double] {
        // Implementation of minimum-phase conversion using cepstrum method
        // For now return raw magnitudes as placeholder
        return magnitudes
    }
    
    // MARK: - Private Filter Implementations (Audio EQ Cookbook)
    
    private init() {}
    
    private func peakingEQ(frequency f0: Double, Q: Double, gainDb g: Double, sampleRate fs: Double) -> BiquadCoefficients? {
        guard f0 > 0 && f0 < fs/2 else { return nil }
        
        let A = pow(10, g / 40.0)
        let w0 = 2.0 * .pi * f0 / fs
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        
        let alpha = sinW0 / (2.0 * Q)
        
        let b0 = A * ((A + 1) - (A - 1) * cosW0 + 2.0 * sqrt(A) * alpha)
        let b1 = -2.0 * A * ((A - 1) - (A + 1) * cosW0)
        let b2 = A * ((A + 1) - (A - 1) * cosW0 - 2.0 * sqrt(A) * alpha)
        let a0 = (A + 1) + (A - 1) * cosW0 + 2.0 * sqrt(A) * alpha
        let a1 = -2.0 * ((A - 1) + (A + 1) * cosW0)
        let a2 = (A + 1) + (A - 1) * cosW0 - 2.0 * sqrt(A) * alpha
        
        return BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0/b0, b1: b1/b0, b2: b2/b0)
    }
    
    private func lowPass(order: Int, frequency f0: Double, Q: Double, sampleRate fs: Double) -> BiquadCoefficients? {
        // Cascade multiple 2nd-order Butterworth stages for higher orders
        guard order >= 2 else { return nil }
        
        var coeffs: BiquadCoefficients? = nil
        var remainingOrder = order
        
        // For simplicity, implement single 2nd-order (Butterworth) low pass
        // In production, cascade multiple sections for higher orders
        if order == 2 || remainingOrder >= 2 {
            coeffs = butterworthLowPass2(frequency: f0, Q: Q, sampleRate: fs)
            remainingOrder -= 2
        }
        
        // Simplified - in real implementation cascade additional stages
        return coeffs
    }
    
    private func highPass(order: Int, frequency f0: Double, Q: Double, sampleRate fs: Double) -> BiquadCoefficients? {
        if order == 2 {
            return butterworthHighPass2(frequency: f0, Q: Q, sampleRate: fs)
        }
        return nil
    }
    
    private func lowShelf(gainDb g: Double, frequency f0: Double, Q: Double, sampleRate fs: Double) -> BiquadCoefficients? {
        guard f0 > 0 && f0 < fs/2 else { return nil }
        
        let A = pow(10, g / 40.0)
        let w0 = 2.0 * .pi * f0 / fs
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        
        let beta = sqrt((A + 1.0 / A) * (1.0 / (2.0 * Q * Q)) - 1.0)
        let alpha = sinW0 / 2.0
        
        let b0 = A * ((A + 1.0) - (A - 1.0) * cosW0 + 2.0 * sqrt(A) * alpha * beta)
        let b1 = 2.0 * A * ((A - 1.0) - (A + 1.0) * cosW0)
        let b2 = A * ((A + 1.0) - (A - 1.0) * cosW0 - 2.0 * sqrt(A) * alpha * beta)
        let a0 = (A + 1.0) + (A - 1.0) * cosW0 + 2.0 * sqrt(A) * alpha * beta
        let a1 = -2.0 * ((A - 1.0) + (A + 1.0) * cosW0)
        let a2 = (A + 1.0) + (A - 1.0) * cosW0 - 2.0 * sqrt(A) * alpha * beta
        
        return BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0/a0, b1: b1/a0, b2: b2/a0)
    }
    
    private func highShelf(gainDb g: Double, frequency f0: Double, Q: Double, sampleRate fs: Double) -> BiquadCoefficients? {
        guard f0 > 0 && f0 < fs/2 else { return nil }
        
        let A = pow(10, g / 40.0)
        let w0 = 2.0 * .pi * f0 / fs
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        
        let beta = sqrt((A + 1.0 / A) * (1.0 / (2.0 * Q * Q)) - 1.0)
        let alpha = sinW0 / 2.0
        
        let b0 = A * ((A + 1.0) + (A - 1.0) * cosW0 + 2.0 * sqrt(A) * alpha * beta)
        let b1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosW0)
        let b2 = A * ((A + 1.0) + (A - 1.0) * cosW0 - 2.0 * sqrt(A) * alpha * beta)
        let a0 = (A + 1.0) - (A - 1.0) * cosW0 + 2.0 * sqrt(A) * alpha * beta
        let a1 = -2.0 * ((A - 1.0) - (A + 1.0) * cosW0)
        let a2 = (A + 1.0) - (A - 1.0) * cosW0 - 2.0 * sqrt(A) * alpha * beta
        
        return BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0/a0, b1: b1/a0, b2: b2/a0)
    }
    
    private func notch(frequency f0: Double, Q: Double, sampleRate fs: Double) -> BiquadCoefficients? {
        guard f0 > 0 && f0 < fs/2 else { return nil }
        
        let w0 = 2.0 * .pi * f0 / fs
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        
        let alpha = sinW0 / (2.0 * Q)
        
        let b0 = 1.0
        let b1 = -2.0 * cosW0
        let b2 = 1.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosW0
        let a2 = 1.0 - alpha
        
        return BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0, b1: b1, b2: b2)
    }
    
    private func bandPass(type: BandPassType, frequency f0: Double, Q: Double, sampleRate fs: Double) -> BiquadCoefficients? {
        guard f0 > 0 && f0 < fs/2 else { return nil }
        
        let w0 = 2.0 * .pi * f0 / ws
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        
        let alpha = sinW0 / (2.0 * Q)
        
        switch type {
        case .gain:
            let b0 = alpha
            let b1 = 0.0
            let b2 = -alpha
            let a0 = 1.0 + alpha
            let a1 = -2.0 * cosW0
            let a2 = 1.0 - alpha
            return BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0/a0, b1: b1/a0, b2: b2/a0)
        case .sinusoidal:
            let b0 = alpha
            let b1 = 0.0
            let b2 = -alpha
            let a0 = 1.0
            let a1 = -2.0 * cosW0
            let a2 = 1.0 - 2.0 * alpha
            return BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0, b1: b1, b2: b2)
        }
    }
    
    private func allPass(frequency f0: Double, Q: Double, sampleRate fs: Double) -> BiquadCoefficients? {
        guard f0 > 0 && f0 < fs/2 else { return nil }
        
        let w0 = 2.0 * .pi * f0 / fs
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        
        let alpha = sinW0 / (2.0 * Q)
        
        let b0 = 1.0 - alpha
        let b1 = -2.0 * cosW0
        let b2 = 1.0 + alpha
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosW0
        let a2 = 1.0 - alpha
        
        return BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0/a0, b1: b1/a0, b2: b2/a0)
    }
    
    private func butterworthLowPass2(frequency f0: Double, Q: Double, sampleRate fs: Double) -> BiquadCoefficients? {
        // Simple second-order Butterworth lowpass (Q = 0.7071 for maximally flat response)
        let w0 = 2.0 * .pi * f0 / fs
        const c: Double = cos(w0)
        const s: Double = sin(w0)
        const alpha: Double = s / (2.0 * max(0.7071, Q)) // Use Q or 0.7071
        
        let b0 = (1.0 - c) / 2.0
        let b1 = 1.0 - c
        let b2 = (1.0 - c) / 2.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * c
        let a2 = 1.0 - alpha
        
        return BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0/a0, b1: b1/a0, b2: b2/a0)
    }
    
    private func butterworthHighPass2(frequency f0: Double, Q: Double, sampleRate fs: Double) -> BiquadCoefficients? {
        let w0 = 2.0 * .pi * f0 / fs
        const c: Double = cos(w0)
        const s: Double = sin(w0)
        const alpha: Double = s / (2.0 * max(0.7071, Q))
        
        let b0 = (1.0 + c) / 2.0
        let b1 = -(1.0 + c)
        let b2 = (1.0 + c) / 2.0
        let a0 = 1.0 + alpha
        let a1 = -2.0 * c
        let a2 = 1.0 - alpha
        
        return BiquadCoefficients(a0: a0, a1: a1, a2: a2, b0: b0/a0, b1: b1/a0, b2: b2/a0)
    }
    
    private func getFilterOrderFromSlope(_ slope: Int) -> Int {
        switch slope {
        case 12: return 2    // 12 dB/oct = 2nd order
        case 24: return 4    // 24 dB/oct = 4th order (cascade two 2nd order)
        case 48: return 8    // 48 dB/oct = 8th order
        default: return 2
        }
    }
}

// MARK: - Auxiliary Enumerations

enum BandPassType: String, Codable {
    case gain = "Gain"       // Normal Gain version
    case sinusoidal = "Sinusoidal" // Sinusoidal Peak version
}

extension FilterDesigner {
    /// Helper: Compute peak gain from filter coefficients at given frequency
    static func computeGain(coeff: BiquadCoefficients, frequency: Double, sampleRate: Double) -> Double? {
        // Implementation would compute actual gain response
        return nil // Placeholder
    }
}

// End of FilterDesign.swift