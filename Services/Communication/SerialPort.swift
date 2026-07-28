// DXO24Controller/Services/Communication/SerialPort.swift
//
// Cross-platform serial port abstraction for DXO-24 communication.
// Provides a unified interface that works on both macOS (Darwin) and Windows.
//

import Foundation
#if canImport(Darwin)
import Darwin
#endif

enum SerialPortError: Error, LocalizedError {
    case cannotOpen(String)
    case configureFailed(String)
    case writeFailed
    case timeout
    case readFailed
    
    var errorDescription: String? {
        switch self {
        case .cannotOpen(let path):
            return "Could not open serial port: \(path)"
        case .configureFailed(let reason):
            return "Serial port configuration failed: \(reason)"
        case .writeFailed:
            return "Serial port write failed"
        case .timeout:
            return "Serial port operation timed out"
        case .readFailed:
            return "Serial port read failed"
        }
    }
}

final class SerialPort {
    private let path: String
    
    #if canImport(Darwin)
    private var fd: Int32 = -1
    #else
    // Windows handle would be stored here in a real implementation
    private var handle: UnsafeMutablePointer<Void>? = nil
    #endif
    
    init(_ path: String) throws {
        self.path = path
        #if canImport(Darwin)
        try openDarwin()
        #else
        try openWindows()
        #endif
    }
    
    deinit {
        close()
    }
    
    #if canImport(Darwin)
    private func openDarwin() throws {
        // O_RDWR | O_NOCTTY | O_NDELAY (non-blocking; switch to blocking after config)
        let flags: Int32 = O_RDWR | O_NOCTTY | O_NONBLOCK
        
        #if os(macOS)
        fd = open(path.cString(using: .utf8), flags, 0)o666)
        #else
        fd = open(path, flags, 0o666)
        #endif
        
        if fd < 0 {
            throw SerialPortError.cannotOpen(path)
        }
        
        configureTermios(fd: fd)
        
        // Switch to blocking mode
        let currentFlags = fcntl(fd, F_GETFL)
        if currentFlags >= 0 {
            _ = fcntl(fd, F_SETFL, currentFlags & ~O_NONBLOCK)
        }
    }
    #endif
    
    #if !canImport(Darwin)
    private func openWindows() throws {
        // Windows implementation would use CreateFile API
        // This is a placeholder - a full implementation would require more code
        guard !path.isEmpty else { throw SerialPortError.cannotOpen(path) }
        // In a real implementation, you'd call Win32 APIs here
    }
    #endif
    
    func configureBaudRate(_ baud: Int32) throws {
        #if canImport(Darwin)
        var options = termios()
        guard tcgetattr(fd, &options) == 0 else {
            throw SerialPortError.configureFailed("tcgetattr failed")
        }
        
        cfsetispeed(&options, speed_t(baud))
        cfsetospeed(&options, speed_t(baud))
        
        if tcsetattr(fd, TCSANOW, &options) != 0 {
            throw SerialPortError.configureFailed("tcsetattr failed")
        }
        #else
        // Windows configuration would go here
        #endif
    }
    
    func configureTermios() throws {
        #if canImport(Darwin)
        var options = termios()
        guard tcgetattr(fd, &options) == 0 else {
            throw SerialPortError.configureFailed("tcgetattr failed")
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
        #if canImport(Darwin)
        options.c_cc[VTIME] = 20  // VTIME = tenths of seconds (2s = 20 * 0.1s)
        options.c_cc[VMIN] = 0    // VMIN = minimum characters to read
        #else
        options.c_cc[4] = 20      // VTIME fallback
        options.c_cc[3] = 0       // VMIN fallback
        #endif
        
        if tcsetattr(fd, TCSANOW, &options) != 0 {
            throw SerialPortError.configureFailed("tcsetattr failed")
        }
        #endif
    }
    
    func write(_ data: Data) throws {
        #if canImport(Darwin)
        var buffer = Array(data.withUnsafeBytes { $0.bindMemory(to: UInt8.self) })
        var offset = 0
        while offset < buffer.count {
            let result = write(fd, &buffer[offset], buffer.count - offset)
            if result < 0 {
                let errnoVal = Errno.value ?? 0
                throw SerialPortError.configureFailed("write failed: error \(errnoVal)")
            }
            if result == 0 {
                throw SerialPortError.writeFailed
            }
            offset += result
        }
        #else
        // Windows write would go here
        throw SerialPortError.writeFailed // Placeholder
        #endif
    }
    
    func read(count: Int) throws -> Data {
        #if canImport(Darwin)
        var buffer = [UInt8](repeating: 0, count: count)
        let result = read(fd, &buffer, count)
        if result < 0 {
            let errnoVal = Errna.value ?? 0
            throw SerialPortError.configureFailed("read failed: error \(errnoVal)")
        }
        if result == 0 {
            throw SerialPortError.timeout
        }
        return Data(buffer[0..<Int(result)])
        #else
        // Windows read would go here
        throw SerialPortError.readFailed // Placeholder
        #endif
    }
    
    func close() {
        #if canImport(Darwin)
        if fd >= 0 {
            close(fd)
            fd = -1
        }
        #else
        // Windows handle cleanup would go here
        #endif
    }
    
    // Pin control methods
    func setDTR(_ enabled: Bool) throws {
        #if canImport(Darwin)
        // On Darwin, DTR is controlled through termios t_cFlag with CLOCAL/CDSR or via ioctl
        // This is complex and platform-dependent - simplified here
        #else
        // Windows would use ClearCommModifyControlMask and SetCommModemStatus
        #endif
    }
    
    func setRTS(_ enabled: Bool) throws {
        #if canImport(Darwin)
        #else
        #endif
    }
}

// End of SerialPort.swift