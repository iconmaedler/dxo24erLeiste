// DXO24Controller/Models/ExpertiseLevel.swift
//
// Three-tier expertise system that drives UI complexity and defaults.

import Foundation

/// User expertise level controlling visible controls and contextual help depth.
enum ExpertiseLevel: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case expert

    var localizedName: String {
        switch self {
        case .beginner:     return "Beginner"
        case .intermediate: return "Intermediate"
        case .expert:       return "Expert"
        }
    }

    /// Whether to expose phase delay and polarity controls.
    var showsPhase: Bool {
        self != .beginner
    }

    /// Whether to show raw numeric values rather than simplified labels.
    var showsRawValues: Bool {
        self == .expert
    }

    /// Whether expert-only FIR / advanced filter options are enabled.
    var enablesFIR: Bool {
        self == .expert
    }

    /// Number of EQ bands visible at this level.
    var maxVisibleEQBands: Int {
        switch self {
        case .beginner:     return 3
        case .intermediate: return 5
        case .expert:       return 7
        }
    }
}
