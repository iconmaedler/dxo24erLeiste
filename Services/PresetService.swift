// DXO24Controller/Services/PresetService.swift
//
// Preset persistence using JSON files in the user's Application Support directory.

import Foundation

enum PresetService {
    static let folderName = "DXO24Controller"
    static let presetExtension = "dxo24"

    static var presetsDirectory: URL? {
        let fm = FileManager.default
        guard let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return url.appendingPathComponent(folderName, isDirectory: true)
    }

    static func save(_ preset: Preset) throws -> URL {
        guard let directory = PresetService.presetsDirectory else {
            throw NSError(domain: "PresetServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access Application Support directory"])
        }

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let url = directory
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
        guard let directory = PresetService.presetsDirectory else {
            throw NSError(domain: "PresetServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access Application Support directory"])
        }
        
        let fm = FileManager.default
        return try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == presetExtension }
    }

    static func delete(_ preset: Preset) throws {
        guard let directory = PresetService.presetsDirectory else {
            throw NSError(domain: "PresetServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access Application Support directory"])
        }
        let url = directory
            .appendingPathComponent(preset.name)
            .appendingPathExtension(presetExtension)
        try FileManager.default.removeItem(at: url)
    }
}

// End of PresetService.swift