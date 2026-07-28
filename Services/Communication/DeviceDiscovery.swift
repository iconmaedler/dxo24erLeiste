// DXO24Controller/Services/Communication/DeviceDiscovery.swift
//
// Simple discovery service for DXO-24 serial ports.
// Scans /dev/cu.* (macOS) or COM ports (Windows) for CDC ACM devices and returns them in a format
// compatible with RealCommunication.connect(to:) and ASCIICommunication.connect(to:).
//
import Foundation
import os

struct DiscoveredDevice: Identifiable, Hashable {
    let identifier: String  // full device path, e.g. "/dev/cu.usbmodem1234" or "COM3"
    let name: String
    var id: String { identifier }
}

enum DeviceDiscovery {
    private static let logger = Logger(subsystem: "com.example.DXO24Controller", category: "discovery")

    /// Returns all plausibly DXO-24 compatible serial ports.
    static func listAvailableDevices() -> [DiscoveredDevice] {
        #if canImport(Darwin)
        return listAvailableDevicesForDarwin()
        #else
        return listAvailableDevicesForOtherPlatforms()
        #endif
    }
    
    /// Returns all plausibly DXO-24 compatible serial ports filtered by communication mode.
    static func listAvailableDevices(for mode: CommunicationMode) -> [DiscoveredDevice] {
        #if canImport(Darwin)
        return listAvailableDevicesForDarwin(by: mode)
        #else
        return listAvailableDevicesForOtherPlatforms(by: mode)
        #endif
    }
    
    #if canImport(Darwin)
    private static func listAvailableDevicesForDarwin() -> [DiscoveredDevice] {
        return listAvailableDevicesForDarwin(by: .json)
    }
    
    private static func listAvailableDevicesForDarwin(by mode: CommunicationMode) -> [DiscoveredDevice] {
        let fm = FileManager.default
        let devURL = URL(fileURLWithPath: "/dev")
        guard let entries = try? fm.contentsOfDirectory(at: devURL,
                                                         includingPropertiesForKeys: nil) else {
            return []
        }

        let relevantPatterns = mode.defaultPortScanPatterns
        
        return entries
            .map(\.path)
            .filter { path in
                // Filter for serial device paths
                guard path.hasPrefix("/dev/cu.") || path.hasPrefix("/dev/tty.") else { return false }
                
                // Check if any pattern matches
                return relevantPatterns.contains { pattern in
                    path.lowercased().contains(pattern.lowercased())
                }
            }
            .map { path in
                let name = (path as NSString).lastPathComponent
                logger.debug("Discovered candidate DXO-24 port: \(path, privacy: .public)")
                return DiscoveredDevice(identifier: path, name: name)
            }
    }
    #endif
    
    #if !canImport(Darwin)
    private static func listAvailableDevicesForOtherPlatforms() -> [DiscoveredDevice] {
        // Windows would scan COM1, COM2, etc. using SetupDiGetClassDevs and similar APIs
        return [] // Placeholder - no real implementation yet
    }
    
    private static func listAvailableDevicesForOtherPlatforms(by mode: CommunicationMode) -> [DiscoveredDevice] {
        return listAvailableDevicesForOtherPlatforms()
    }
    #endif
}

// End of DeviceDiscovery.swift