// DXO24Controller/Models/SpeakerModel.swift
//
// Reference database of common loudspeaker models used by the
// room calibration and crossover recommendation engine.

import Foundation

/// Reference data for a single loudspeaker model.
struct SpeakerModel: Codable, Equatable, Identifiable {
    var id: String { name }

    let name: String
    let manufacturer: String
    let recommendedCrossover: Double   // Hz
    let frequencyResponseLow: Double   // Hz
    let frequencyResponseHigh: Double  // Hz
    let sensitivity: Double?           // dB SPL @ 1W/1m (optional)
    let wooferSizeInches: Double       // used for placement-based crossover estimation

    // MARK: - static reference database

    static let database: [SpeakerModel] = [
        SpeakerModel(name: "RCF HDL 20-A",        manufacturer: "RCF",
                     recommendedCrossover: 90, frequencyResponseLow: 52, frequencyResponseHigh: 20_000,
                     sensitivity: 134, wooferSizeInches: 12),
        SpeakerModel(name: "d&b E12",              manufacturer: "d&b audiotechnik",
                     recommendedCrossover: 100, frequencyResponseLow: 55, frequencyResponseHigh: 18_000,
                     sensitivity: 132, wooferSizeInches: 12),
        SpeakerModel(name: "Fohhn KN-100",         manufacturer: "Fohhn Audio",
                     recommendedCrossover: 110, frequencyResponseLow: 60, frequencyResponseHigh: 20_000,
                     sensitivity: 124, wooferSizeInches: 10),
        SpeakerModel(name: "KV2 VHD5",             manufacturer: "KV2 Audio",
                     recommendedCrossover: 80,  frequencyResponseLow: 45, frequencyResponseHigh: 18_000,
                     sensitivity: 146, wooferSizeInches: 15),
        SpeakerModel(name: "JBL VTX A12",          manufacturer: "JBL Professional",
                     recommendedCrossover: 95,  frequencyResponseLow: 48, frequencyResponseHigh: 20_000,
                     sensitivity: 138, wooferSizeInches: 12),
        SpeakerModel(name: "QSC K12.2",            manufacturer: "QSC",
                     recommendedCrossover: 100, frequencyResponseLow: 50, frequencyResponseHigh: 20_000,
                     sensitivity: 131, wooferSizeInches: 12),
        SpeakerModel(name: "Electro-Voice ELX200-12", manufacturer: "Electro-Voice",
                     recommendedCrossover: 110, frequencyResponseLow: 52, frequencyResponseHigh: 20_000,
                     sensitivity: 127, wooferSizeInches: 12),
        SpeakerModel(name: "Yamaha DZR12",         manufacturer: "Yamaha",
                     recommendedCrossover: 95,  frequencyResponseLow: 45, frequencyResponseHigh: 20_000,
                     sensitivity: 133, wooferSizeInches: 12),
        SpeakerModel(name: "Meyer Sound ASM-115",  manufacturer: "Meyer Sound",
                     recommendedCrossover: 85,  frequencyResponseLow: 38, frequencyResponseHigh: 20_000,
                     sensitivity: 130, wooferSizeInches: 15),
        SpeakerModel(name: "L-Acoustics X8",       manufacturer: "L-Acoustics",
                     recommendedCrossover: 120, frequencyResponseLow: 65, frequencyResponseHigh: 20_000,
                     sensitivity: 121, wooferSizeInches: 8),
        SpeakerModel(name: "Custom",               manufacturer: "User-defined",
                     recommendedCrossover: 100, frequencyResponseLow: 40, frequencyResponseHigh: 18_000,
                     sensitivity: nil, wooferSizeInches: 12),
    ]
}
