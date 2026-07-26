// DXO24Controller/Views/Components/InfoCard.swift
//
// Reusable inline info popover used throughout the parameter views.

import SwiftUI

struct InfoCard: View {
    let title: String
    let message: String

    @State private var isPopoverOpen = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Button {
                isPopoverOpen.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.tint)
                    .help(message)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPopoverOpen) {
                Text(message)
                    .padding(12)
                    .frame(maxWidth: 260)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
