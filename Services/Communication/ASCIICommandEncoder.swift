// DXO24Controller/Services/Communication/ASCIICommandEncoder.swift
//
// Encodes DeviceCommand into ASCII command strings compatible with DXO-24 serial protocol.
// The DXO-24 typically uses a simple ASCII text protocol where each command is
// terminated by carriage return (\r) and responses echo the command with ACK/NAK.
//
// Example command format:
//   SETL -6.0 0.0\r    -> Set input level to -6.0, output level to 0.0
//   SETMUTE 1 0\r     -> Mute input, unmute output
//   GET\r             -> Request current state
//
import Foundation

/// Encodes DeviceCommand into ASCII string format.
/// Also handles decoding of ASCII response strings back to DeviceResponse.
struct ASCIICommandEncoder {

    /// Encode a command to an ASCII command string.
    static func encode(_ command: DeviceCommand) -> String {
        switch command {
        case let .setLevel(input, output):
            return "SETL \(String(format: "%.1f", input)) \(String(format: "%.1f", output))\r"
        case let .setMute(input, output):
            let inputStr = input ? "1" : "0"
            let outputStr = output ? "1" : "0"
            return "SETPUT \(inputStr) \(outputStr)\r"
        case let .setCrossover(frequency, slope):
            return "XCROSS \(String(format: "%.0f", frequency)) \(slope)\r"
        case let .setEQBand(index, band):
            return "EQBAND \(index) \(String(format: "%.0f", band.frequency)) \(String(format: "%.1f", band.gain)) \(String(format: "%.2f", band.qFactor)) \(band.enabled ? "1" : "0")\r"
        case let .setPhase(delay):
            return "PHASE \(String(format: "%.1f", delay))\r"
        case let .setPolarity(inverted):
            return "POL \(inverted ? "1" : "0")\r"
        case let .setLimiter(threshold):
            return "LIMIT \(String(format: "%.1f", threshold))\r"
        case .requestState:
            return "GET\r"
        case let .unknown(data):
            return "UNK \(data.base64EncodedString())\r"
        }
    }

    /// Decode an ASCII response string to DeviceResponse.
    static func decode(_ response: String) -> DeviceResponse {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Simple ACK handling
        if trimmed == "ACK" || trimmed == "OK" {
            return .ack
        } else if trimmed == "NAK" || trimmed == "ERROR" {
            return .nak
        } else if trimmed.hasPrefix("RESP") {
            // In a real implementation, parse the full state response
            // This would be complex and require JSON or structured parsing
            return .state(.flatPreset) // placeholder
        } else if trimmed.hasPrefix("ERROR:") {
            return .error(String(trimmed.dropFirst(6)))
        } else {
            // Default to success for unknown positive responses
            return .success
        }
    }

    /// Generate DTR/RTS control commands for serial pin management.
    /// These are used to control hardware handshaking pins on the serial port.
    enum SerialPinControl: String, CaseIterable {
        case setDTRHigh = "DTR1\r"
        case setDTRLow  = "DTR0\r"
        case setRTSHigh = "RTS1\r"
        case setRTSLow  = "RTS0\r"
        case queryDTR   = "DTR?\r"
        case queryRTS   = "RTS?\r"
    }
}

// End of ASCIICommandEncoder.swift