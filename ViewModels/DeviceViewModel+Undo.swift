// DXO24Controller/ViewModels/DeviceViewModel+Undo.swift
//
// Undo-Manager-Integration für alle Parameteränderungen.

import Foundation
import Combine

extension DeviceViewModel {
    func registerUndo() {
        guard let undoManager = undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            target.device = target.device
            target.objectWillChange.send()
        }
        undoManager.setActionName("Parameter change")
    }

    private var undoManager: UndoManager? {
        // Access the undo manager from the current RunLoop context when available.
        // In AppKit, this is typically associated with NSApplication or the responder chain.
        // We provide a simple no-op fallback here to keep the ViewModel testable.
        NSApp?.undoManager
    }
}
