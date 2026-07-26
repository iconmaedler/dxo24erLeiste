// DXO24Controller/DesignSystem/Core.swift
//
// Zentrale Design-Token-Typen für die gesamte Anwendung.
// Ersetzen magische Zahlen (8, 12, 16, 0.35, 0.85) durch benannte Konstanten.

import SwiftUI

enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 14
        static let xl: CGFloat = 20
        static let pill: CGFloat = 999
    }

    enum Animation {
        static let spring = Animation.spring(response: 0.35, dampingFraction: 0.82, blendDuration: 0)
        static let easeOut = Animation.easeOut(duration: 0.22)
    }

    enum Elevation {
        static let level1: CGFloat = 2
        static let level2: CGFloat = 6
        static let level3: CGFloat = 12
    }
}
