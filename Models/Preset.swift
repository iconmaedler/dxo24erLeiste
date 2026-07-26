// DXO24Controller/Models/Preset.swift
//
// Serializable preset bundle that captures device state with optional room context.

import Foundation

/// A named preset capturing full device configuration with optional room context.
struct Preset: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var deviceState: DXO24Device
    var roomParameters: RoomParameters?
    var createdAt: Date
    var modifiedAt: Date
    var version: String

    init(id: UUID = UUID(),
         name: String,
         deviceState: DXO24Device,
         roomParameters: RoomParameters? = nil,
         createdAt: Date = Date(),
         modifiedAt: Date? = nil,
         version: String = "1.0") {
        self.id             = id
        self.name           = name
        self.deviceState    = deviceState
        self.roomParameters = roomParameters
        self.createdAt      = createdAt
        self.modifiedAt     = modifiedAt ?? createdAt
        self.version        = version
    }
}
