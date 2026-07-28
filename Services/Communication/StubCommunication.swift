// DXO24Controller/Services/Communication/StubCommunication.swift
//
// Simulation stub used for UI development before real IOUSBHost wiring is complete.
// Only the stub should ever be swapped out at this one boundary.
//
// This implements both JSON and ASCII protocol simulation for testing different modes.
//
import Foundation
import os

final class StubCommunication: DXO24Communication, ObservableObject {
    @Published var isConnected: Bool = false
    @Published var currentState: DXO24Device = .flatPreset
    
    // Track simulated state for recovery after disconnect/reconnect
    private var lastSentState: DXO24Device?
    
    private static let logger = Logger(subsystem: "com.dxo24.controller.communication", category: "stub")

    func connect(to port: String) async throws {
        Self.logger.debug("connect(to: '\(port, privacy: .public)' in stub mode)")
        try await Task.sleep(nanoseconds: 100_000_000) // Simulate 100ms connection delay
        await MainActor.run { self.isConnected = true }
        Self.logger.debug("connected in stub mode")
    }

    func disconnect() {
        Self.logger.debug("disconnect in stub mode")
        isConnected = false
    }

    func send(_ command: DeviceCommand) async throws -> DeviceResponse {
        guard isConnected else { throw CommunicationError.notConnected }
        Self.logger.debug("send: \(command.description, privacy: .public) [STUB]")
        try await Task.sleep(nanoseconds: 100_000_000) // Simulate 100ms round-trip
        
        await MainActor.run {
            Self.apply(command, to: &self.currentState)
            self.lastSentState = self.currentState
        }
        
        // Return ack or success based on command type
        switch command {
        case .requestState:
            return .state(self.currentState)
        case .unknown:
            return .ack
        default:
            return .success
        }
    }

    func readState() async throws -> DXO24Device {
        guard isConnected else { throw CommunicationError.notConnected }
        try await Task.sleep(nanoseconds: 100_000_000)
        return currentState
    }

    // MARK: - Private

    private static func apply(_ command: DeviceCommand, to state: inout DXO24Device) {
        switch command {
        case let .setLevel(i, o):
            state.inputLevel = i; state.outputLevel = o
        case let .setMute(i, o):
            state.inputMute = i; state.outputMute = o
        case let .setCrossover(f, s):
            state.crossoverFrequency = f; state.crossoverSlope = s
        case let .setEQBand(idx, band) where idx >= 0 && idx < state.eqBands.count:
            state.eqBands[idx] = band
        case let .setPhase(d):
            state.phaseDelay = d
        case let .setPolarity(b):
            state.polarity = b
        case let .setLimiter(d):
            state.limiterThreshold = d
        case .requestState, .unknown:
            ()
        }
    }
    
    /// Reset to factory settings (used for testing state recovery)
    func resetToFactory() {
        currentState = .flatPreset
        lastSentState = nil
    }
}

// End of StubCommunication.swift