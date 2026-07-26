// DXO24Controller/Models/Amplifier.swift
//
// Repräsentiert eine zusätzliche, externe Endstufe (Verstärker) die an den DXO-24 angeschlossen ist.
// Der Nutzer kann hier definieren, welche Daisy‑Chain‑/ serielle‑/ USB‑Verbindung genutzt wird,
// welche Lautsprecher extern dazu laufen und wie sie eingestellt werden sollen.
//
import Foundation

struct Amplifier: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var manufacturer: String
    var model: String
    var serial: String
    var channels: Int                       // 1 (Mono) … 8 (Mehrkanal)
    var powerPerChannel: Double            // Watt RMS @ 8 Ω
    var gainDb: Double                     // -12 … +12 dB
    var isPowered: Bool                    // Ab‑/An‑Schaltung (z.B. Stecker oder 12 V Trigger)
    var isBridged: Bool
    var connection: Connection
    var inputSource: String                // z.B. "Output A", "Output B/Mono", "Dante 1"
    var assignedSpeakers: [SpeakerAssignment]
    var dspSettings: DSPSettings

    init(id: UUID = UUID(),
         name: String = "Neue Endstufe",
         manufacturer: String = "",
         model: String = "",
         serial: String = "",
         channels: Int = 2,
         powerPerChannel: Double = 500,
         gainDb: Double = 0,
         isPowered: Bool = false,
         isBridged: Bool = false,
         connection: Connection = .daisyChain,
         inputSource: String = "Output A",
         assignedSpeakers: [SpeakerAssignment] = [],
         dspSettings: DSPSettings = .init()) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.model = model
        self.serial = serial
        self.channels = channels
        self.powerPerChannel = powerPerChannel
        self.gainDb = gainDb
        self.isPowered = isPowered
        self.isBridged = isBridged
        self.connection = connection
        self.inputSource = inputSource
        self.assignedSpeakers = assignedSpeakers
        self.dspSettings = dspSettings
    }

    var powerWattsSafe: Double {
        isBridged ? powerPerChannel * 2.5 : powerPerChannel
    }

    var channelsInUse: Int {
        isBridged ? max(1, channels / 2) : channels
    }

    enum Connection: String, Codable, Equatable, CaseIterable, Identifiable {
        case daisyChain    = "Daisy-Chain (Thru)"
        case parallel     = "Parallel‑Out"
        case usb           = "USB‑Audio"
        case dante         = "Dante"
        case aesEb67       = "AES/EBU"
        case trigger       = "12 V Trigger nur"
        case other         = "Andere"

        var id: String { rawValue }
        var iconName: String {
            switch self {
            case .daisyChain: return "link"
            case .parallel:   return "cable.connector"
            case .usb:         return "usb.device.symbol"
            case .dante:       return "network"
            case .aesEb67:     return "wave.3.right"
            case .trigger:     return "bolt.fill"
            case .other:       return "questionmark.circle"
            }
        }
    }

    struct SpeakerAssignment: Codable, Equatable, Identifiable {
        let id: UUID
        var name: String                   // z.B. "Lautsprecher L"
        var outputChannel: Int             // 1 … channels
        var polarityInverted: Bool
        var lpFilter: Double                // Hz, 0 = aus
        var hpFilter: Double                // Hz, 0 = aus
        var delayMs: Double                 // ms
        var isActive: Bool

        init(id: UUID = UUID(),
             name: String = "Neuer Lautsprecher",
             outputChannel: Int = 1,
             polarityInverted: Bool = false,
             lpFilter: Double = 0,
             hpFilter: Double = 0,
             delayMs: Double = 0,
             isActive: Bool = true) {
            self.id = id
            self.name = name
            self.outputChannel = outputChannel
            self.polarityInverted = polarityInverted
            self.lpFilter = lpFilter
            self.hpFilter = hpFilter
            self.delayMs = delayMs
            self.isActive = isActive
        }
    }

    struct DSPSettings: Codable, Equatable {
        var crossoverHighHz: Double          // 20 … 20 000, 0 = aus
        var compressorEnabled: Bool
        var compressorThresholdDb: Double
        var limiterThresholdDb: Double
        var limiterMode: LimiterMode
        var protection: Bool                 // peak‑limiter / Schutzschaltung

        init(crossoverHighHz: Double = 2000,
             compressorEnabled: Bool = false,
             compressorThresholdDb: Double = -6,
             limiterThresholdDb: Double = -3,
             limiterMode: LimiterMode = .peak,
             protection: Bool = true) {
            self.crossoverHighHz = crossoverHighHz
            self.compressorEnabled = compressorEnabled
            self.compressorThresholdDb = compressorThresholdDb
            self.limiterThresholdDb = limiterThresholdDb
            self.limiterMode = limiterMode
            self.protection = protection
        }

        enum LimiterMode: String, Codable, Equatable, CaseIterable, Identifiable {
            case peak       = "Peak‑Limiter"
            case trueRms    = "True‑RMS"
            case brickwall  = "Brickwall"
            var id: String { rawValue }
        }
    }
}

// End of Amplifier.swift
