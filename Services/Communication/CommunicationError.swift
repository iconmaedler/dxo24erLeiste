// DXO24Controller/Services/Communication/CommunicationError.swift
//
// Communication domain errors. Adopt LocalizedError so SwiftUI can present descriptions.

import Foundation

/// Errors specific to device communication.
enum CommunicationError: LocalizedError, Equatable {
    case notConnected
    case invalidResponse(String)
    case timeout
    case unknown

    var errorDescription: String? {
        switch self {
        case .notConnected:     return "Device is not connected."
        case .invalidResponse(let detail): return "Invalid response from device: \(detail)"
        case .timeout:          return "Communication with device timed out."
        case .unknown:          return "Unknown communication error."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notConnected: return "Connect the DXO-24 with a supported USB adapter and try again."
        case .timeout:      return "Check the USB cable and reconnect."
        default:            return nil
        }
    }
}
