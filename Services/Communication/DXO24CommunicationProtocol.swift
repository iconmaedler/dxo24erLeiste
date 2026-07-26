// DXO24Controller/Services/Communication/DXO24CommunicationProtocol.swift
//
// Abstraction layer over the physical link to a DXO-24 device.
// Implementations may use: IOUSBHost (preferred), IOKit HID, or IOKit serial.
// DO NOT use POSIX termios for native raw USB — that path is only for virtual COM ports.

import Foundation

// Forward-reference note: DXO24Device and EQBand are in the same Xcode target
// and compile fine even without an explicit import here.

/// Abstraction over the physical link to a DXO-24 device.
protocol DXO24Communication: AnyObject {
    func connect(to port: String) async throws
    func disconnect()
    func send(_ command: DeviceCommand) async throws -> DeviceResponse
    func readState() async throws -> DXO24Device
}

extension DXO24Communication {
    /// Sends a command with basic retry semantics. Retries on .nak and .error only.
    func sendAndWait(_ command: DeviceCommand, retries: Int = 2) async throws -> DeviceResponse {
        var last: DeviceResponse = .nak
        for attempt in 0 ... retries {
            last = try await send(command)
            switch last {
            case .success, .ack, .state: return last
            case .nak, .error:           if attempt == retries { throw CommunicationError.invalidResponse(last.description) }
            case .unknown:               if attempt == retries { throw CommunicationError.invalidResponse("unknown") }
            }
        }
        return last
    }
}

// MARK: - Commands

/// High-level command sent from the UI to the device.
enum DeviceCommand: Codable, Equatable {
    case setLevel(input: Double, output: Double)
    case setMute(input: Bool, output: Bool)
    case setCrossover(frequency: Double, slope: Int)
    case setEQBand(index: Int, band: EQBand)
    case setPhase(Double)
    case setPolarity(Bool)
    case setLimiter(Double)
    case requestState
    case unknown(Data)

    var description: String {
        switch self {
        case let .setLevel(i, o):       return "setLevel(\(i), \(o))"
        case let .setMute(i, o):        return "setMute(\(i), \(o))"
        case let .setCrossover(f, s):   return "setCrossover(\(f), \(s))"
        case let .setEQBand(i, b):      return "setEQBand(\(i), \(b.frequency))"
        case let .setPhase(d):          return "setPhase(\(d))"
        case let .setPolarity(b):       return "setPolarity(\(b))"
        case let .setLimiter(d):        return "setLimiter(\(d))"
        case .requestState:             return "requestState"
        case let .unknown(data):        return "unknown(\(data.count) bytes)"
        }
    }
}

/// Response returned by the device for a given command.
enum DeviceResponse: Codable, Equatable {
    case success
    case ack
    case nak
    case error(String)
    case state(DXO24Device)

    var description: String {
        switch self {
        case .success: return "success"
        case .ack:     return "ack"
        case .nak:     return "nak"
        case let .error(s): return "error(\(s))"
        case .state:   return "state"
        }
    }
}
