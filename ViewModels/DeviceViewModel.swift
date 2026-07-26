// DXO24Controller/ViewModels/DeviceViewModel.swift
//
// Zentrale Orchestrierungsschicht zwischen Views, CalculationService und Communication.
// Besitzt die alleinige Wahrheitsquelle für den Gerätezustand.

import Foundation

final class DeviceViewModel: ObservableObject {
    @Published var device: DXO24Device = .flatPreset
    @Published var isConnected: Bool = false
    @Published var connectionError: CommunicationError?
    @Published var headroomWarning: String?

    private let communication: DXO24Communication

    init(communication: DXO24Communication = RealCommunication()) {
        self.communication = communication
    }

    //MARK: - Verbindung

    func connect(to port: String) async {
        connectionError = nil
        do {
            try await communication.connect(to: port)
            await MainActor.run { self.isConnected = true }
        } catch {
            await MainActor.run { self.connectionError = error as? CommunicationError ?? .unknown }
        }
    }

    func disconnect() {
        communication.disconnect()
        isConnected = false
    }

    //MARK: - Schreibvorgänge Gerät

    func sendLevels() async {
        do {
            let response = try await communication.sendAndWait(.setLevel(input: device.inputLevel, output: device.outputLevel))
            await handleResponse(response)
        } catch {
            await MainActor.run { self.connectionError = error as? CommunicationError ?? .unknown }
        }
    }

    func sendMutes() async {
        do {
            let response = try await communication.sendAndWait(.setMute(input: device.inputMute, output: device.outputMute))
            await handleResponse(response)
        } catch {
            await MainActor.run { self.connectionError = error as? CommunicationError ?? .unknown }
        }
    }

    func sendCrossover() async {
        do {
            let response = try await communication.sendAndWait(.setCrossover(frequency: device.crossoverFrequency, slope: device.crossoverSlope))
            await handleResponse(response)
        } catch {
            await MainActor.run { self.connectionError = error as? CommunicationError ?? .unknown }
        }
    }

    func sendEQBand(at index: Int) async {
        guard index >= 0 && index < device.eqBands.count else { return }
        do {
            let response = try await communication.sendAndWait(.setEQBand(index: index, band: device.eqBands[index]))
            await handleResponse(response)
        } catch {
            await MainActor.run { self.connectionError = error as? CommunicationError ?? .unknown }
        }
    }

    func sendPhase() async {
        do {
            let response = try await communication.sendAndWait(.setPhase(device.phaseDelay))
            await handleResponse(response)
        } catch {
            await MainActor.run { self.connectionError = error as? CommunicationError ?? .unknown }
        }
    }

    func sendPolarity() async {
        do {
            let response = try await communication.sendAndWait(.setPolarity(device.polarity))
            await handleResponse(response)
        } catch {
            await MainActor.run { self.connectionError = error as? CommunicationError ?? .unknown }
        }
    }

    func sendLimiter() async {
        do {
            let response = try await communication.sendAndWait(.setLimiter(device.limiterThreshold))
            await handleResponse(response)
        } catch {
            await MainActor.run { self.connectionError = error as? CommunicationError ?? .unknown }
        }
    }

    func refreshState() async {
        do {
            let state = try await communication.readState()
            await MainActor.run { self.device = state }
        } catch {
            await MainActor.run { self.connectionError = error as? CommunicationError ?? .unknown }
        }
    }

    //MARK: - Berechnungen

    func updateHeadroomWarning() {
        let positiveGains = device.eqBands.filter { $0.enabled }.map { max(0, $0.gain) }.reduce(0, +)
        let result = CalculationService.checkHeadroom(eqGainSum: positiveGains, amplifierHeadroom: 12.0)
        headroomWarning = result.warning
    }

    //MARK: - Privat

    @MainActor
    private func handleResponse(_ response: DeviceResponse) {
        if case let .error(message) = response {
            connectionError = .invalidResponse(message)
        }
    }
}
