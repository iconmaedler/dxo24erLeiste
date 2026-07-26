// DXO24Controller/Models/RoomParameters.swift
//
// Room acoustic parameters used by CalculationService and the Calibration wizard.

import Foundation

/// Encapsulates the physical characteristics of the listening room.
struct RoomParameters: Codable, Equatable {
    var width: Double         // 1.0 ... 50.0 m
    var depth: Double         // 1.0 ... 50.0 m
    var height: Double        // 1.0 ... 50.0 m
    var surface: Surface      // absorption quality
    var listeningDistance: Double // 0.5 ... 10.0 m
    var speakerPlacement: Placement
    var subwooferEnabled: Bool

    enum Surface: String, Codable, CaseIterable {
        case hard, medium, soft

        /// Estimated absorption coefficient for RT60 calculations.
        var absorptionCoefficient: Double {
            switch self {
            case .hard:   return 0.10
            case .medium: return 0.30
            case .soft:   return 0.60
            }
        }

        var localizedName: String {
            switch self {
            case .hard:   return "Hard (concrete, glass)"
            case .medium: return "Medium (wood, drywall)"
            case .soft:   return "Soft (carpet, curtains)"
            }
        }
    }

    enum Placement: String, Codable, CaseIterable {
        case freeStanding, wall, corner

        var localizedName: String {
            switch self {
            case .freeStanding: return "Free-standing"
            case .wall:          return "Wall"
            case .corner:        return "Corner"
            }
        }
    }

    // MARK: - Init

    init(width: Double         = 5.0,
         depth: Double         = 5.0,
         height: Double        = 2.8,
         surface: Surface      = .medium,
         listeningDistance: Double  = 2.0,
         speakerPlacement: Placement = .freeStanding,
         subwooferEnabled: Bool = false) {
        self.width            = width
        self.depth            = depth
        self.height           = height
        self.surface          = surface
        self.listeningDistance = listeningDistance
        self.speakerPlacement = speakerPlacement
        self.subwooferEnabled = subwooferEnabled
    }

    enum ValidationError: String, Error {
        case dimensionOutOfRange      = "Room dimensions must be 1 ... 50 m"
        case listeningDistanceOutOfRange = "Listening distance must be 0.5 ... 10.0 m"
    }

    func validate() throws {
        for dimension in [width, depth, height] {
            guard (1.0 ... 50.0).contains(dimension) else {
                throw ValidationError.dimensionOutOfRange
            }
        }
        guard (0.5 ... 10.0).contains(listeningDistance) else {
            throw ValidationError.listeningDistanceOutOfRange
        }
    }

    // MARK: - Derived geometry

    var volume: Double       { width * depth * height }
    var totalSurface: Double { 2.0 * (width * depth + width * height + depth * height) }
}
