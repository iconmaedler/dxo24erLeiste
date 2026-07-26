import Foundation
import Darwin

/// Verwaltet die echte RS-232-Kommunikation mit dem DXO-24 über USB-zu-Seriell-Adapter.
/// Unterstützt automatisch: FTDI, Prolific, Silicon Labs (CP210x), QinHeng (CH340/CH341).
@MainActor
final class SerialCommunicationService: DXO24Communication, ObservableObject {
    
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Nicht verbunden"
    @Published var availablePorts: [String] = []
    @Published var selectedPort: String = ""
    
    private var serialPort: NativeSerialPort?
    private var debounceTimer: Timer?
    private var pendingCommands: [Data] = []
    private var readThread: Thread?
    private var shouldContinueReading: Bool = false
    
    static let shared = SerialCommunicationService()
    
    // MARK: - DXO-24 Protokoll-Konstanten
    // HINWEIS: Ersetze diese Werte mit den Ergebnissen aus protocol_mapping.csv!
    struct Protocol {
        static let header: UInt8 = 0xF0
        static let footer: UInt8 = 0x0D // CR
        
        // Opcodes (aus protocol.pyc extrahiert)
        static let opcodeGet: UInt8 = 0x00
        static let opcodeSet: UInt8 = 0x01
        static let opcodeRsp: UInt8 = 0x02
        static let opcodeErr: UInt8 = 0x03
        
        // Struct IDs (Placeholder - mit CSV abgleichen!)
        static let structGain: UInt8 = 0x10
        static let structMixer: UInt8 = 0x11
        static let structDelay: UInt8 = 0x12
        static let structLimiter: UInt8 = 0x13
        static let structMute: UInt8 = 0x14
        static let structInvert: UInt8 = 0x15
        static let structCompressor: UInt8 = 0x16
        static let structChannel: UInt8 = 0x17
        static let structFIR: UInt8 = 0x18
        
        // Member IDs (Placeholder - mit CSV abgleichen!)
        static let memberGain: UInt8 = 0x20
        static let memberFreq: UInt8 = 0x21
        static let memberQ: UInt8 = 0x22
        static let memberType: UInt8 = 0x23
        static let memberThreshold: UInt8 = 0x24
        static let memberAttack: UInt8 = 0x25
        static let memberRelease: UInt8 = 0x26
        static let memberMute: UInt8 = 0x28
        static let memberInvert: UInt8 = 0x29
    }
    
    init() {
        refreshAvailablePorts()
    }
    
    func refreshAvailablePorts() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "ls /dev/cu.usbserial* /dev/cu.usbmodem* /dev/cu.SLAB_USBtoUART* /dev/cu.wchusbserial* 2>/dev/null | sort"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let ports = output.split(separator: "\n")
                    .map { String($0).trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                
                self.availablePorts = ports
                if ports.isEmpty {
                    self.connectionStatus = "Kein RS-232-Adapter gefunden"
                    self.isConnected = false
                } else {
                    self.connectionStatus = "\(ports.count) Adapter gefunden. Bitte wählen."
                    if self.selectedPort.isEmpty {
                        self.selectedPort = ports.first ?? ""
                    }
                }
            }
        } catch {
            self.connectionStatus = "Fehler beim Scannen der Ports"
            self.availablePorts = []
        }
    }
    
    // MARK: - DXO24Communication Protocol
    
    func connect(to port: String) async throws {
        connectionStatus = "Verbinde mit \(port)..."
        let portService = NativeSerialPort(portPath: port)
        
        guard portService.open() else {
            isConnected = false
            connectionStatus = "Fehler: Port belegt oder keine Berechtigung"
            throw CommunicationError.connectionFailed("Kann Port nicht öffnen: \(port)")
        }
        
        self.serialPort = portService
        self.isConnected = true
        self.selectedPort = port
        self.connectionStatus = "Verbunden: \(port)"
        
        // Starte Read-Thread
        shouldContinueReading = true
        readThread = Thread { [weak self] in
            self?.readLoop()
        }
        readThread?.start()
        
        print("✅ Erfolgreich verbunden mit \(port)")
    }
    
    func disconnect() {
        shouldContinueReading = false
        serialPort?.close()
        serialPort = nil
        isConnected = false
        connectionStatus = "Getrennt"
        readThread = nil
    }
    
    func send(_ command: DeviceCommand) async throws -> DeviceResponse {
        guard isConnected, let port = serialPort else {
            throw CommunicationError.notConnected
        }
        
        let frame = buildFrame(from: command)
        if !port.write(frame) {
            throw CommunicationError.connectionFailed("Schreibfehler auf seriellen Port")
        }
        
        // TODO: Implementiere Antwort-Lesen mit Timeout
        return .ack
    }
    
    func readState() async throws -> DXO24Device {
        guard isConnected else {
            throw CommunicationError.notConnected
        }
        // TODO: Implementiere vollständiges State-Reading
        return .flatPreset
    }
    
    // MARK: - Private Methoden
    
    private func buildFrame(from command: DeviceCommand) -> Data {
        var data = Data()
        data.append(Protocol.header)
        
        switch command {
        case let .setLevel(input, output):
            data.append(Protocol.opcodeSet)
            data.append(Protocol.structGain)
            data.append(Protocol.memberGain)
            data.append(0) // Channel 0
            let levelBytes = encodeFloat(Float32(output))
            data.append(UInt8(levelBytes.count))
            data.append(levelBytes)
            
        case let .setMute(_, output):
            data.append(Protocol.opcodeSet)
            data.append(Protocol.structMute)
            data.append(Protocol.memberMute)
            data.append(0) // Channel 0
            data.append(1) // Length
            data.append(output ? 1 : 0)
            
        case let .setPolarity(enabled):
            data.append(Protocol.opcodeSet)
            data.append(Protocol.structInvert)
            data.append(Protocol.memberInvert)
            data.append(0) // Channel 0
            data.append(1) // Length
            data.append(enabled ? 1 : 0)
            
        case let .setCrossover(frequency, _):
            data.append(Protocol.opcodeSet)
            data.append(Protocol.structDelay)
            data.append(Protocol.memberFreq)
            data.append(0) // Channel 0
            let freqBytes = encodeFloat(Float32(frequency))
            data.append(UInt8(freqBytes.count))
            data.append(freqBytes)
            
        case let .setEQBand(index, band):
            data.append(Protocol.opcodeSet)
            data.append(Protocol.structFIR)
            data.append(Protocol.memberFreq)
            data.append(UInt8(index))
            var payload = Data()
            payload.append(contentsOf: encodeFloat(Float32(band.frequency)))
            payload.append(contentsOf: encodeFloat(Float32(band.q)))
            payload.append(contentsOf: encodeFloat(Float32(band.gain)))
            data.append(UInt8(payload.count))
            data.append(payload)
            
        case let .setPhase(delay):
            data.append(Protocol.opcodeSet)
            data.append(Protocol.structDelay)
            data.append(Protocol.memberFreq)
            data.append(0) // Channel 0
            let delayBytes = encodeFloat(Float32(delay))
            data.append(UInt8(delayBytes.count))
            data.append(delayBytes)
            
        case let .setLimiter(threshold):
            data.append(Protocol.opcodeSet)
            data.append(Protocol.structLimiter)
            data.append(Protocol.memberThreshold)
            data.append(0) // Channel 0
            let threshBytes = encodeFloat(Float32(threshold))
            data.append(UInt8(threshBytes.count))
            data.append(threshBytes)
            
        case .requestState:
            data.append(Protocol.opcodeGet)
            data.append(Protocol.structChannel)
            data.append(0)
            data.append(0)
            data.append(0)
            
        case let .unknown(rawData):
            data.append(rawData)
        }
        
        // Checksumme berechnen (XOR aller Bytes außer Header)
        var checksum: UInt8 = 0
        for i in 1..<data.count {
            checksum ^= data[i]
        }
        data.append(checksum)
        data.append(Protocol.footer)
        
        return data
    }
    
    private func encodeFloat(_ value: Float32) -> Data {
        var value = value
        return Data(bytes: &value, count: MemoryLayout<Float32>.size)
    }
    
    private func readLoop() {
        var buffer = Data()
        let readBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 256)
        defer { readBuffer.deallocate() }
        
        while shouldContinueReading {
            guard let port = serialPort else { break }
            
            let bytesRead = Darwin.read(port.fileDescriptor, readBuffer, 256)
            if bytesRead > 0 {
                buffer.append(readBuffer, count: bytesRead)
                // TODO: Frame-Parsing implementieren
            }
            
            usleep(10000) // 10ms
        }
    }
    
    deinit {
        disconnect()
    }
}

// MARK: - Native POSIX Serial Port Wrapper

class NativeSerialPort {
    var fileDescriptor: Int32 = -1
    private let portPath: String
    
    init(portPath: String) {
        self.portPath = portPath
    }
    
    func open() -> Bool {
        fileDescriptor = Darwin.open(portPath, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fileDescriptor >= 0 else { return false }
        
        var options = termios()
        guard tcgetattr(fileDescriptor, &options) == 0 else {
            close()
            return false
        }
        
        cfmakeraw(&options)
        options.c_cflag |= (CLOCAL | CREAD)
        options.c_cflag &= ~CSIZE
        options.c_cflag |= CS8
        options.c_cflag &= ~PARENB
        options.c_cflag &= ~CSTOPB
        
        cfsetispeed(&options, B9600)
        cfsetospeed(&options, B9600)
        
        guard tcsetattr(fileDescriptor, TCSANOW, &options) == 0 else {
            close()
            return false
        }
        
        return true
    }
    
    func write(_ data: Data) -> Bool {
        guard fileDescriptor >= 0 else { return false }
        let bytesWritten = data.withUnsafeBytes { rawBufferPointer in
            Darwin.write(fileDescriptor, rawBufferPointer.baseAddress, rawBufferPointer.count)
        }
        return bytesWritten > 0
    }
    
    func close() {
        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
        }
    }
    
    deinit {
        close()
    }
}
