// DXO24Controller/ViewModels/DeviceViewModel.swift
//
// Zentrale Orchestrierungsschicht zwischen Views, CalculationService und Communication.
// Besitzt die alleinige Wahrheitsquelle für den Gerätezustand.

import Foundation
import Combine

final class DeviceViewModel: ObservableObject {
    @Published var device: DXO24Device = .flatPreset
    @Published var isConnected: Bool = false
    @Published var connectionError: CommunicationError?
    @Published var headroomWarning: String?
    
    // Current communication mode
    @Published var communicationMode: CommunicationMode = .json
    
    private let communication: DXO24Communication
    private var cancellables = Set<AnyCancellable>()
    
    init(communication: DXO24Communication = RealCommunication()) {
        self.communication = communication
        setupCommunicationObservables()
    }

    // MARK: - Verbindung

    func connect(to port: String) async {
        connectionError = nil
        do {
            try await communication.connect(to: port)
            await MainActor.run { self.isConnected = true }
        } catch {
            await MainActor.run { 
                self.connectionError = error as? CommunicationError ?? .unknown
            }
        }
    }

    func disconnect() {
        communication.disconnect()
        isConnected = false
        connectionError = nil
    }

    func setCommunicationMode(_ mode: CommunicationMode) {
        // In a real implementation, you'd swap the underlying communication implementation
        // based on the mode. For now this is just tracked for UI purposes.
        communicationMode = mode
    }

    //MARK: - Schreibvorgänge Gerät with improved handling

    func sendLevels() async {
        guard isConnected else { return }
        do {
            let response = try await communication.sendAndWait(.setLevel(input: device.inputLevel, output: device.outputLevel))
            await handleResponse(response)
        } catch {
            await MainActor.run { 
                self.connectionError = (error as? CommunicationError) ?? .unknown 
            }
        }
    }

    func sendMutes() async {
        guard isConnected else { return }
        do {
            let response = try await communication.sendAndWait(.setMute(input: device.inputMute, output: device.outputMute))
            await handleResponse(response)
        } catch {
            await MainActor.run { 
                self.connectionError = (error as? CommunicationError) ?? .unknown 
            }
        }
    }

    func sendCrossover() async {
        guard isConnected else { return }
        do {
            let response = try await communication.sendAndWait(.setCrossover(frequency: device.crossoverFrequency, slope: device.crossoverSlope))
            await handleResponse(response)
        } catch {
            await MainActor.run { 
                self.connectionError = (error as? CommunicationError) ?? .unknown 
            }
        }
    }

    func sendEQBand(at index: Int) async {
        guard index >= 0 && index < device.eqBands.count, isConnected else { return }
        do {
            let response = try await communication.sendAndWait(.setEQBand(index: index, band: device.eqBands[index]))
            await handleResponse(response)
        } catch {
            await MainActor.run { 
                self.connectionError = (error as? CommunicationError) ?? .unknown 
            }
        }
    }

    func sendPhase() async {
        guard isConnected else { return }
        do {
            let response = try await communication.sendAndWait(.setPhase(device.phaseDelay))
            await handleResponse(response)
        } catch {
            await MainActor.run { 
                self.connectionError = (error as? CommunicationError) ?? .unknown 
            }
        }
    }

    func sendPolarity() async {
        guard isConnected else { return }
        do {
            let response = try await communication.sendAndWait(.setPolarity(device.polarity))
            await handleResponse(response)
        } catch {
            await MainActor.run { 
                self.connectionError = (error as? CommunicationError) ?? .unknown 
            }
        }
    }

    func sendLimiter() async {
        guard isConnected else { return }
        do {
            let response = try await communication.sendAndWait(.setLimiter(device.limiterThreshold))
            await handleResponse(response)
        } catch {
            await MainActor.run { 
                self.connectionError = (error as? CommunicationError) ?? .unknown 
            }
        }
    }

    func refreshState() async {
        guard isConnected else { return }
        do {
            let state = try await communication.readState()
            await MainActor.run { self.device = state }
            connectionError = nil
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
        switch response {
        case .error(let message):
            connectionError = .invalidResponse(message)
        case .success, .ack:
            // Clear transient errors on successful responses
            if case .invalidResponse? = connectionError {
                connectionError = nil
            }
        default:
            break
        }
    }

    private func setupCommunicationObservables() {
        // Observe connection state changes from the communication implementation
        // This handles the case where external code modifies isConnected
    }
}

extension Optional {
    /// Safe unwrapping that returns a default value
    func orElse(_ defaultVal: T) -> T {
        self ?? defaultVal
    }
}

// End of DeviceViewModel.swift