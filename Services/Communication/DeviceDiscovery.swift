// DXO24Controller/Services/Communication/DeviceDiscovery.swift
//
// Simple discovery service for DXO-24 serial ports.
// Scans /dev/cu.* (macOS) for CDC ACM devices and returns them in a format
// compatible with RealCommunication.connect(to:).
//
import Foundation
import os

struct DiscoveredDevice: Identifiable, Hashable {
    let identifier: String  // full device path, e.g. "/dev/cu.usbmodem1234"
    let name: String
    var id: String { identifier }
}

enum DeviceDiscovery {
    private static let logger = Logger(subsystem: "com.example.DXO24Controller", category: "discovery")

    /// Returns all `/dev/cu.*` devices that plausibly belong to the DXO-24.
    static func listAvailableDevices() -> [DiscoveredDevice] {
        let fm = FileManager.default
        let devURL = URL(fileURLWithPath: "/dev")
        guard let entries = try? fm.contentsOfDirectory(at: devURL,
                                                         includingPropertiesForKeys: nil) else {
            return []
        }

        return entries
            .map(\.path)
            .filter { $0.hasPrefix("/dev/cu.") && ($0.contains("usbmodem") || $0.contains("usbserial")) }
            .map { path in
                let name = (path as NSString).lastPathComponent
                logger.debug("Discovered candidate DXO-24 port: \(path, privacy: .public)")
                return DiscoveredDevice(identifier: path, name: name)
            }
    }
}

// End of DeviceDiscovery.swift
