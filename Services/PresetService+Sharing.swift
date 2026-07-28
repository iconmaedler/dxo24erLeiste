// DXO24Controller/Services/PresetService+Sharing.swift
//
// Erweiterung von PresetService mit Austausch- und Export-Funktionalität.
// Ermöglicht das Versenden von Presets per Email, AirDrop oder Cloud-Speicher.
//
import Foundation

extension PresetService {
    // MARK: - Export / Import
    
    /// Exportiert ein Preset als komprimierte JSON-Datei mit Metadaten
    static func export(_ preset: Preset, to url: URL) throws {
        // Erstelle ein Bundle mit dem Preset-JSON + Metadateien
        let bundleURL = url.deletingPathExtension()
        
        // Haupt-Preset-Datei
        let presetData = try JSONEncoder().encode(preset)
        try presetData.write(to: bundleURL.appendingPathComponent("preset.json"))
        
        // Metadaten
        let metadata: [String: Any] = [
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "version": "1.0",
            "deviceType": "DXO24"
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)
        try metadataData.write(to: bundleURL.appendingPathComponent("metadata.plist"))
        
        // Optional: Room-Parameter einbetten
        if let room = preset.roomParameters {
            let roomData = try JSONEncoder().encode(room)
            try roomData.write(to: bundleURL.appendingPathComponent("room.json"))
        }
        
        // Bundle verpacken (Optional für .bundle Format)
        // ...
    }
    
    /// Importiert ein Preset aus einer exportierten Datei oder einem Bundle
    static func import(from url: URL) throws -> Preset {
        var preset: Preset?
        
        // Entweder directe JSON-Datei oder ein Bundle
        if url.pathExtension == "json" || url.pathExtension == "dxo24" {
            preset = try load(from: url)
        } else if url.hasDirectoryPath {
            // Verzeichnis als Bundle behandeln
            let presetURL = url.appendingPathComponent("preset.json")
            if FileManager.default.fileExists(atPath: presetURL.path) {
                preset = try load(from: presetURL)
            }
        }
        
        guard let p = preset else {
            throw NSError(domain: "PresetImportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ungültiges Preset-Format"])
        }
        
        return p
    }
    
    /// Sendet das aktuelle Preset über die Standard-Sharing-UI
    static func shareCurrentPreset(_ preset: Preset, from view: NSView?) {
        let item = NSURL(fileURL: getTemporaryDirectory())
        do {
            // Export temporär
            try export(preset, to: item as URL)
            
            // Share Sheet aufrufen
            let sharingItem = NSItemProvider()
            try? loadDataRepresentation(forTypeIdentifier: publicUTI) for use in: { data in
                sharingItem.setDataForTypeIdentifier(publicUTI, data: data)
            }
            
            let animator = NSAnimator(sharedItems: [sharingItem])
            animator.animate(with: view)
        } catch {
            // Fehlerbehandlung (Alert dem User zeigen)
        }
    }
    
    private static func getTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
    }
    
    private static let publicUTI = "com.dxo24.preset" // Custom UTI, needs to be registered in Info.plist
}

// End of PresetService+Sharing.swift