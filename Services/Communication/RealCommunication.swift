// DXO24Controller/Services/Communication/RealCommunication.swift
//
// Real communication implementation for the Omnitronic DXO-24 device.
//
// Many USB audio controllers expose a virtual serial port (CDC ACM) and accept
// a simple JSON command framing. This implementation opens the serial device
// referenced by the "port" string (e.g. "/dev/cu.usbmodem1234" on macOS or
// "COM3" on Windows), configures the line discipline for 115200 8N1, and
// exchanges length-prefixed JSON frames.
//
import Foundation
import os

@MainActor
final class RealCommunication: DXO24Communication, ObservableObject {
    @Published var isConnected: Bool = false
    @Published var currentState: DXO24Device = .flatPreset

    private var fileHandle: FileHandle?
    private var serialPort: SerialPort? // For raw access if needed
    private static let logger = Logger(subsystem: "com.example.DXO24Controller", category: "communication")

    // MARK: - DXO24Communication protocol

    func connect(to port: String) async throws {
        disconnect()

        guard !port.isEmpty else { throw CommunicationError.invalidResponse("No port specified") }

        #if canImport(Darwin)
        // On Darwin, use POSIX FileHandle with open() directly
        let fd = openPort(port)
        guard fd >= 0 else {
            throw CommunicationError.invalidResponse("Could not open serial port: \(port)")
        }
        configureTermios(fd: fd)

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        self.fileHandle = handle
        #else
        // On other platforms (Windows), use SerialPort abstraction
        do {
            serialPort = try SerialPort(port)
            try serialPort?.configureBaudRate(115200)
            try serialPort?.configureTermios()
        } catch {
            throw CommunicationError.invalidResponse("Could not open serial port: \(error.localizedDescription)")
        }
        #endif

        self.isConnected = true
        Self.logger.debug("Connected to DXO-24 at \(port, privacy: .public)")

        // Best-effort: read the initial device state.
        if let initial = try? await readState() {
            self.currentState = initial
        }
    }

    func disconnect() {
        #if canImport(Darwin)
        try? fileHandle?.close()
        fileHandle = nil
        #else
        serialPort = nil
        #endif
        isConnected = false
        Self.logger.debug("Disconnected from DXO-24 device")
    }

    func send(_ command: DeviceCommand) async throws -> DeviceResponse {
        #if canImport(Darwin)
        guard let handle = fileHandle else { throw CommunicationError.notConnected }
        #else
        guard serialPort != else { throw CommunicationError.notConnected }
        #endif

        let encoder = JSONEncoder()
        let payload = try encoder.encode(command)

        // Frame: [2-byte little-endian length][payload]
        var lenLE = UInt16(payload.count).littleEndian
        let header = Data(bytes: &lenLE, count: 2)
        let packet = header + payload
        
        #if canImport(Darwin)
        try writeAll(handle: handle, data: packet)
        #else
        // For Windows, write through serialPort
        // (implementation would go here)
        #endif

        // Read response frame.
        let responsePayload = try readFrame()
        return try JSONDecoder().decode(DeviceResponse.self, from: responsePayload)
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
            throw CommunicationError.invalidResponse("Unexpected response: \(response)")
        }
    }

    // MARK: - POSIX serial helpers (Darwin only)

    #if canImport(Darwin)
    private func openPort(_ port: String) -> Int32 {
        // O_RDWR | O_NOCTTY | O_NDELAY (non-blocking; switch to blocking after config)
        let flags: Int32 = O_RDWR | O_NOCTTY | O_NONBLOCK
        return open(port.cString(using: .utf8) ?? "", flags, 0o666)
    }

    private func configureTermios(fd: Int32) {
        var options = termios()
        guard tcgetattr(fd, &options) == 0 else {
            throw CommunicationError.invalidResponse("tcgetattr failed")
        }

        // 115200 baud, 8 data bits, no parity, 1 stop bit (8N1)
        cfsetispeed(&options, speed_t(B115200))
        cfsetospeed(&options, speed_t(B115200))

        // Control flags: 8N1, enable receiver, ignore modem control lines.
        options.c_cflag |= UInt(CLOCAL | CREAD)
        options.c_cflag &= ~UInt(PARENB)
        options.c_cflag &= ~UInt(CSTOPB)
        options.c_cflag &= ~UInt(CSIZE)
        options.c_cflag |= UInt(CS8)

        // Local flags: raw mode.
        options.c_lflag &= ~(UInt(ICANON) | UInt(ECHO) | UInt(ECHOE) | UInt(ISIG))

        // Input flags: disable software flow control and special input handling.
        options.c_iflag &= ~(UInt(IXON) | UInt(IXOFF) | UInt(IXANY))
        options.c_iflag &= ~(UInt(INLCR) | UInt(ICRNL))

        // Output flags: raw output.
        options.c_oflag &= ~UInt(OPOST)

        // Set timeouts: blocking read with 2s timeout.
        options.c_cc[VTIME] = 20  // VTIME = tenths of seconds (2s = 20 * 0.1s)
        options.c_cc[VMIN] = 0    // VMIN = minimum characters to read

        if tcsetattr(fd, TCSANOW, &options) != 0 {
            throw CommunicationError.invalidResponse("tcsetattr failed")
        }

        // Switch to blocking mode.
        let currentFlags = fcntl(fd, F_GETFL)
        if currentFlags >= 0 {
            _ = fcntl(fd, F_SETFL, currentFlags & ~O_NONBLOCK)
        }
    }
    #endif

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

    private func readFrame() throws -> Data {
        #if canImport(Darwin)
        guard let handle = fileHandle else { throw CommunicationError.notConnected }
        // Read 2-byte length header.
        let header = try readExact(handle: handle, count: 2)
        let count = UInt16(header[0]) | (UInt16(header[1]) << 8)
        guard count > 0, count <= 65535 else {
            throw CommunicationError.invalidResponse("Invalid frame length")
        }
        return try readExact(handle: handle, count: Int(count))
        #else
        // Windows implementation would read from serialPort
        throw CommunicationError.invalidResponse("Not implemented on this platform")
        #endif
    }

    private func readExact(handle: FileHandle, count: Int) throws -> Data {
        var buffer = Data()
        while buffer.count < count {
            let chunk = try handle.read(upToCount: count - buffer.count) ?? Data()
            if chunk.isEmpty {
                throw CommunicationError.timeout
            }
            buffer.append(chunk)
        }
        return buffer
    }
}

// End of RealCommunication.swift