// DXO24Controller/Services/Communication/StubCommunication.swift
//
// Simulation stub used for UI development before real IOUSBHost wiring is complete.
// Only the stub should ever be swapped out at this one boundary.

import Foundation
import os

/// Stub transport that simulates device round-trip with 100 ms latency.
/// No files here. In production, replace this type with IOUSBHost-backed implementation.
final class StubCommunication: DXO24Communication, ObservableObject {
    @Published var isConnected: Bool = false
    @Published var currentState: DXO24Device = .flatPreset

    private static let logger = Logger(subsystem: "com.dxo24.controller.communication", category: "stub")

    func connect(to port: String) async throws {
        Self.logger.debug("connect(to: '\(port, privacy: .public)')")
        try await Task.sleep(nanoseconds: 100_000_000)
        await MainActor.run { self.isConnected = true }
        Self.logger.debug("connected")
    }

    func disconnect() {
        Self.logger.debug("disconnect")
        isConnected = false
    }

    func send(_ command: DeviceCommand) async throws -> DeviceResponse {
        guard isConnected else { throw CommunicationError.notConnected }
        Self.logger.debug("send: \(command.description, privacy: .public)")
        try await Task.sleep(nanoseconds: 100_000_000)
        await MainActor.run {
            Self.apply(command, to: &self.currentState)
        }
        return .ack
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
}
