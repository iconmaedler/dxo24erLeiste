// DXO24Controller/Services/Communication/CommunicationMode.swift
//
// Defines the available communication modes for the DXO-24 controller.
// Users can switch between JSON-framed protocol (binary-safe) and ASCII text protocol
// (human-readable, compatible with older firmware versions).

import Foundation

enum CommunicationMode: String, CaseIterable, Codable {
    case json      = "JSON"  // Default: length-prefixed JSON frames
    case ascii     = "ASCII" // Text-based commands with \r termination
    
    var description: String {
        switch self {
        case .json: return "JSON-framed protocol (binary-safe)"
        case .ascii: return "ASCII text protocol (human-readable)"
        }
    }
    
    var defaultPortScanPatterns: [String] {
        switch self {
        case .json: return ["usbmodem", "usbserial", "tty"]
        case .ascii: return ["usbmodem", "usbserial", "tty", "COM"]
        }
    }
}

// Extension for DeviceDiscovery to support different port scanning patterns per mode
extension DeviceDiscovery {
    static func listAvailableDevices(for mode: CommunicationMode) -> [DiscoveredDevice] {
        let fm = FileManager.default
        let devURL = URL(fileURLWithPath: "/dev")
        guard let entries = try? fm.contentsOfDirectory(at: devURL, includingPropertiesForKeys: nil) else {
            return []
        }
        
        let patterns = mode.defaultPortScanPatterns
        return entries
            .map(\.path)
            .filter { path in
                let hasPrefix = path.hasPrefix("/dev/cu.") || path.hasPrefix("COM")
                return patterns.contains { pattern in
                    path.lowercased().contains(pattern.lowercased())
                } && hasPrefix
            }
            .map { path in
                let name = (path as NSString).lastPathComponent
                logger.debug("Discovered candidate DXO-24 port: \(path, privacy: .public)")
                return DiscoveredDevice(identifier: path, name: name)
            }
    }
}

// End of CommunicationMode.swift