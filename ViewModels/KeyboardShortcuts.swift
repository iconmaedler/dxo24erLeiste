// DXO24Controller/ViewModels/KeyboardShortcuts.swift
//
// Centralized keyboard shortcut management for DXO24Controller.
// Implements macOS-style modifier keys (⌘, ⌥, ⇧, ⌃) mapping to common actions.
//
import Foundation
import SwiftUI

/// Global Application-wide Shortcut Registry
final class KeyboardShortcutRegistry: ObservableObject {
    static let shared = KeyboardShortcutRegistry()
    
    // Define all available shortcuts as an enum
    enum Action: String, CaseIterable, Codable {
        case savePreset           = "SavePreset"        // Cmd+S
        case loadPreset           = "LoadPreset"        // Cmd+O
        case deletePreset         = "DeletePreset"      // Delete
        case startMeasurement     = "StartMeasurement"  // Space
        case stopMeasurement      = "StopMeasurement"   // Space (toggle)
        case showParameters       = "ShowParameters"    // Cmd+1
        case showCalibration      = "ShowCalibration"   // Cmd+2
        case showRoomPlanner      = "ShowRoomPlanner"   // Cmd+3
        case showPresetView       = "ShowPresetView"    // Cmd+4
        case toggleEQ             = "ToggleEQ"          // Cmd+E
        case resetDevice          = "ResetDevice"       // Cmd+R
        
        var localizedName: String {
            switch self {
            case .savePreset: return "Speichern"
            case .loadPreset: return "Laden"
            case .deletePreset: return "Löschen"
            case .startMeasurement: return "Messung Starten"
            case .stopMeasurement: return "Messung Stoppen"
            case .showParameters: return "Parameter"
            case .showCalibration: return "Kalibrierung"
            case .showRoomPlanner: return "Raum-Planer"
            case .showPresetView: return "Presets"
            case .toggleEQ: return "EQ umschalten"
            case .resetDevice: return "Zurücksetzen"
            }
        }
        
        var defaultModifier: NSEventModifierFlags {
            switch self {
            case .savePreset, .loadPreset, .deletePreset, .resetDevice:
                return .commandKeyMask
            case .startMeasurement, .stopMeasurement:
                return [] // Just space
            case .showParameters: return .commandKeyMask + .number1Mask
            case .showCalibration: return .commandKeyMask + .number2Mask
            case .showRoomPlanner: return .commandKeyMask + .number3Mask
            case .showPresetView: return .commandKeyMask + .number4Mask
            case .toggleEQ: return .commandKeyMask + .letterMEask
            }
        }
        
        var defaultKey: String {
            switch self {
            case .savePreset: return "s"
            case .loadPreset: return "o"
            case .deletePreset: return "delete"
            case .startMeasurement, .stopMeasurement: return "space"
            case .showParameters: return "1"
            case .showCalibration: return "2"
            case .showRoomPlanner: return "3"
            case .showPresetView: return "4"
            case .toggleEQ: return "e"
            case .resetDevice: return "r"
            }
        }
        
        var shortcutString: String {
            if modifierFlags.isEmpty {
                return key
            } else {
                let modifierParts: [String] = [
                    modifierFlags.contains(.commandKeyMask) ? "⌘" : "",
                    modifierFlags.contains(.optionKeyMask) ? "⌥" : "",
                    modifierFlags.contains(.shiftKeyMask) ? "⇧" : "",
                    modifierFlags.contains(.controlKeyMask) ? "⌃" : ""
                ].filter { !$0.isEmpty }
                
                return modifierParts.joined(separator: " + ") + " + \(key)"
            }
        }
        
        private var modifierFlags: NSEventModifierFlags {
            switch self {
            case .savePreset, .loadPreset, .deletePreset, .showParameters, .showCalibration, .showRoomPlanner, .showPresetView, .toggleEQ, .resetDevice:
                return .commandKeyMask
            case .startMeasurement, .stopMeasurement:
                return []
            }
        }
        
        private var key: String {
            switch self {
            case .savePreset: return "S"
            case .loadPreset: return "O"
            case .deletePreset: return "⌫"
            case .startMeasurement, .stopMeasurement: return "Space"
            case .showParameters: return "1"
            case .showCalibration: return "2"
            case .showRoomPlanner: return "3"
            case .showPresetView: return "4"
            case .toggleEQ: return "E"
            case .resetDevice: return "R"
            }
        }
    }
    
    @Published var shortcuts: [Action: NSEventModifierFlags + KeyCombo] = [:]
    
    private init() {
        initializeDefaultShortcuts()
    }
    
    func initializeDefaultShortcuts() {
        shortcuts = [
            .savePreset: [.commandKeyMask, .letterMask('s')],
            .loadPreset: [.commandKeyMask, .letterMask('o')],
            .deletePreset: [.deleteKeyMask],
            .startMeasurement: [.spaceKeyMask],
            .stopMeasurement: [.spaceKeyMask],
            .showParameters: [.commandKeyMask, .number1Mask],
            .showCalibration: [.commandKeyMask, .number2Mask],
            .showRoomPlanner: [.commandKeyMask, .number3Mask],
            .showPresetView: [.commandKeyMask, .number4Mask],
            .toggleEQ: [.commandKeyMask, .letterMask('e')],
            .resetDevice: [.commandKeyMask, .letterMask('r')]
        ]
    }
    
    func shortcutFor(_ action: Action) -> String? {
        let modifiers = shortcuts[action]?.filter { $0 != .spaceKeyMask && $0 != .deleteKeyMask && $0 != .letterMask("s") && $0 != .letterMask("o") && $0 != .letterMask("e") && $0 != .letterMask("r") && $0 != .number1Mask && $0 != .number2Mask && $0 != .number3Mask && $0 != .number4Mask }
        if let modifiers = modifiers, !modifiers.isEmpty {
            return modifiers.compactMap { flag in
                switch flag {
                case .commandKeyMask: return "⌘"
                case .optionKeyMask: return "⌥"
                case .shiftKeyMask: return "⇧"
                case .controlKeyMask: return "⌃"
                default: return nil
                }
            }.joined(separator: " + ") + " + "
        }
        return nil
    }
}

// MARK: - NSEvent Modifier Flag Extensions

extension NSEventModifierFlags {
    static func letterMask(_ char: Character) -> NSEventModifierFlags {
        // This would be a real implementation that maps char to keycode
        return self // Placeholder
    }
    
    static var deleteKeyMask: NSEventModifierFlags { return self }
    static var spaceKeyMask: NSEventModifierFlags { return self }
}

// MARK: - View Extension for Shortcut Binding

extension View {
    /// Adds keyboard shortcut binding to view
    func onShortcut(_ action: KeyboardShortcutRegistry.Action, perform @escaping () -> Void) -> some View {
        self.modifierKey(ShortcutKeyBinding(action: action, perform: perform))
    }
}

struct ShortcutKeyBinding<Content>: View where Content: View {
    let action: KeyboardShortcutRegistry.Action
    let perform: () -> Void
    let content: Content
    
    init(action: KeyboardShortcutRegistry.Action, @ViewBuilder content: () -> Content) {
        self.action = action
        self.perform = perform
        self.content = content()
    }
    
    var body: some View {
        content
            .onKeyDown { event in
                if matchesShortcut(event) {
                    perform()
                    event.preventBubbling()
                }
            }
    }
    
    private func matchesShortcut(_ event: NSEvent?) -> Bool {
        guard let event = event, event.type == .keyDown else { return false }
        
        let registry = KeyboardShortcutRegistry.shared
        guard let requiredModifiers = registry.shortcuts[action] else { return false }
        
        // Check if event modifiers match (simplified check)
        // In production, compare actual event.modifierFlags with required
        return true // Placeholder logic
    }
}

// End of KeyboardShortcuts.swift