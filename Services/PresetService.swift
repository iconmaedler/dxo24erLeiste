// DXO24Controller/Services/PresetService.swift
//
// Preset persistence using JSON files in the user's Application Support directory.

import Foundation

enum PresetService {
    static let folderName = "DXO24Controller"
    static let presetExtension = "dxo24"

    static var presetsDirectory: URL {
        let fm = FileManager.default
        let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(folderName, isDirectory: true)
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func save(_ preset: Preset) throws -> URL {
        let url = presetsDirectory
            .appendingPathComponent(preset.name)
            .appendingPathExtension(presetExtension)
        let data = try JSONEncoder().encode(preset)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    static func load(from url: URL) throws -> Preset {
        let data = try Data(contentsOf: url)
        let preset = try JSONDecoder().decode(Preset.self, from: data)
        return preset
    }

    static func listPresets() throws -> [URL] {
        let fm = FileManager.default
        return try fm.contentsOfDirectory(at: presetsDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == presetExtension }
    }

    static func delete(_ preset: Preset) throws {
        let url = presetsDirectory
            .appendingPathComponent(preset.name)
            .appendingPathExtension(presetExtension)
        try FileManager.default.removeItem(at: url)
    }
}
