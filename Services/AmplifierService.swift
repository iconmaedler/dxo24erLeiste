// DXO24Controller/Services/AmplifierService.swift
//
// Persistiert die Liste der zusätzlichen Endstufen im Application‑Support‑Verzeichnis.
// Atomares Schreiben wie PresetService – gleiche Schutzeigenschaften.
//
import Foundation

enum AmplifierService {
    static let folderName = "DXO24Controller/Amplifiers"
    static let ampExtension = "amplist"

    static var directory: URL {
        let fm = FileManager.default
        let url = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(folderName, isDirectory: true)
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func save(_ amp: Amplifier) throws -> URL {
        let url = directory
            .appendingPathComponent(amp.id.uuidString)
            .appendingPathExtension(ampExtension)
        let data = try JSONEncoder().encode(amp)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    static func load(from url: URL) throws -> Amplifier {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Amplifier.self, from: data)
    }

    static func listAll() throws -> [Amplifier] {
        let fm = FileManager.default
        return try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == ampExtension }
            .compactMap { try? load(from: $0) }
    }

    static func delete(_ amp: Amplifier) throws {
        let url = directory
            .appendingPathComponent(amp.id.uuidString)
            .appendingPathExtension(ampExtension)
        try FileManager.default.removeItem(at: url)
    }
}

// End of AmplifierService.swift
