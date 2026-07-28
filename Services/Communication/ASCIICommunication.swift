// DXO24Controller/Services/Communication/ASCIICommunication.swift
//
// ASCII-based communication implementation for DXO-24 devices that use text-based
// serial commands instead of JSON framing. This is useful when the hardware expects
// simple ASCII commands like "SETL -6.0 0.0\r\n" with simple ACK/NAK responses.
//
import Foundation
import os

@MainActor
final class ASCIICommunication: DXO24Communication, ObservableObject {
    @Published var isConnected: Bool = false
    @Published var currentState: DXO24Device = .flatPreset

    private var fileHandle: FileHandle?
    private static let logger = Logger(subsystem: "com.example.DXO24Controller", category: "asciiComm")

    func connect(to port: String) async throws {
        disconnect()
        guard !port.isEmpty else { throw CommunicationError.invalidResponse("No port specified") }

        #if canImport(Darwin)
        let fd = openPort(port)
        guard fd >= 0 else {
            throw CommunicationError.invalidResponse("Could not open serial port: \(port)")
        }
        configureTermios(fd: fd)
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        self.fileHandle = handle
        #else
        // Windows ASCII support placeholder
        Self.logger.warning("ASCII communication on Windows not yet fully implemented")
        throw CommunicationError.invalidResponse("ASCIICommunication not supported on this platform")
        #endif

        self.isConnected = true
        Self.logger.debug("Connected to DXO-24 at \(port, privacy: .public) using ASCII protocol")

        // Reset device with a known command
        try await sendResetCommand()
        
        if let initial = try? await readState() {
            self.currentState = initial
        }
    }

    func disconnect() {
        try? fileHandle?.close()
        fileHandle = nil
        isConnected = false
        Self.logger.debug("Disconnected from DXO-24 device")
    }

    func send(_ command: DeviceCommand) async throws -> DeviceResponse {
        guard let handle = fileHandle else { throw CommunicationError.notConnected }

        // Encode command to ASCII string
        let asciiString = ASCIICommandEncoder.encode(command)
        let data = Data(asciiString.utf8)

        // Write with newline termination (some devices expect \n instead of \r)
        var outputData = data
        if !asciiString.hasSuffix("\r") && !asciiString.hasSuffix("\n") {
            outputData.append(asciiString.hasSuffix("\r") ? "\n" : "\r\n".data(using: .utf8)!)
        }

        try writeAll(handle: handle, data: outputData)

        // Read response with timeout
        let responseText = try readAsciiResponse(handle: handle, timeoutMs: 1000)

        // Decode response
        let response = ASCIICommandEncoder.decode(responseText)
        return response
    }

    func readState() async throws -> DXO24Device {
        let response = try await send(.requestState)
        switch response {
        case .state(let dev):
            self.currentState = dev
            return dev
        case .error(let msg):
            throw CommunicationError.invalidResponse(msg)
        default:
            // Try to get state by requesting it via ASCII command
            let asciiResponse = try await readAsciiRequestState()
            // Parse asciiResponse into DXO24Device (placeholder - would need full parser)
            self.currentState = asciiResponse ?? .flatPreset
            return self.currentState
        }
    }

    private func writeAll(handle: FileHandle, data: Data) throws {
        var remaining = data
        while !remaining.isEmpty {
            let written = try handle.write(contentsOf: remaining)
            if written <= 0 {
                throw CommunicationError.invalidResponse("USB/Serial write failed")
            }
            remaining = remaining.dropFirst(written)
        }
    }

    private func readAsciiResponse(handle: FileHandle, timeoutMs: Int) throws -> String {
        // Simple response reader - in practice would need better framing detection
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutMs) / 1000.0)
        var response = ""
        
        while Date() < deadline {
            guard let chunk = handle.readUpToCount(1, including: .newlines) ?? Data() else {
                try Task.sleep(nanoseconds: 10000) // Small yield
                continue
            }
            
            if let str = String(data: chunk, encoding: .utf8) {
                response += str
                if response.last == "\r" || response.last == "\n" {
                    break
                }
            }
        }
        
        if response.isEmpty {
            throw CommunicationError.timeout
        }
        
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func readAsciiRequestState() async throws -> DXO24Device? {
        // Send a state query ASCII command
        let response = try await send(.requestState)
        if case .state(let dev) = response {
            return dev
        }
        return nil
    }
    
    private func sendResetCommand() async throws {
        // Send a reset/warmup command to establish communication
        do {
            _ = try await send(.unknown(Data([0x00]))) // Simple warmup byte
        } catch {
            // Ignore warmup failures, they're expected on first connection
            Self.logger.debug("Warmup command ignored (expected)")
        }
    }
    
    #if canImport(Darwin)
    private func openPort(_ port: String) -> Int32 {
        let flags: Int32 = O_RDWR | O_NOCTTY | O_NDELAY
        return open(port.cString(using: .utf8) ?? "", flags, 0o666)
    }
    
    private func configureTermios(fd: Int32) {
        var options = termios()
        guard tcgetattr(fd, &options) == 0 else {
            throw CommunicationError.invalidResponse("tcgetattr failed")
        }
        
        cfsetispeed(&options, speed_t(B115200))
        cfsetospeed(&options, speed_t(B115200))
        
        options.c_cflag |= UInt(CLOCAL | CREAD)
        options.c_cflag &= ~UInt(PARENB)
        options.c_cflag &= ~UInt(CSTOPB)
        options.c_cflag &= ~UInt(CSIZE)
        options.c_cflag |= UInt(CS8)
        
        options.c_lflag &= ~(UInt(ICANON) | UInt(ECHO) | UInt(ECHOE) | UInt(ISIG))
        options.c_iflag &= ~(UInt(IXON) | UInt(IXOFF) | UInt(IXANY))
        options.c_iflag &= ~(UInt(INLCR) | UInt(ICRNL))
        options.c_oflag &= ~UInt(OPOST)
        
        options.c_cc[VTIME] = 10   // 1 second timeout
        options.c_cc[VMIN] = 0      // non-blocking
        
        tcsetattr(fd, TCSANOW, &options)
        
        let currentFlags = fcntl(fd, F_GETFL)
        if currentFlags >= 0 {
            _ = fcntl(fd, F_SETFL, currentFlags & ~O_NONBLOCK)
        }
    }
    #endif
}

extension ASCIICommandEncoder {
    /// Special handling for state request/response in ASCII mode
    static func decodeStateResponse(_ text: String) -> DXO24Device? {
        // This would parse ASCII-formatted state responses like:
        // "I:-6.0 O:0.0 M:0 CM:24 CF:80 PD:0.0 LT:0.0 EQ31.5:0,1000:0..."
        // Full parsing implementation depends on actual DXO-24 ASCII protocol
        return nil // Placeholder
    }
}

// End of ASCIICommunication.swift