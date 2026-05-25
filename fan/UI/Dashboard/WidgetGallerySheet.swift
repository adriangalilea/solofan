//
//  WidgetGallerySheet.swift
//  SoloFan
//
//  iOS-style widget picker for the popover dashboard.
//

import SwiftUI

struct WidgetGallerySheet: View {
    @ObservedObject var store: DashboardStore
    let targetRowID: UUID
    let hasBattery: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredKinds: [DashboardWidgetKind] {
        DashboardWidgetKind.allCases.filter { kind in
            kind.isAvailable(hasBattery: hasBattery)
                && (searchText.isEmpty
                    || kind.displayName.localizedCaseInsensitiveContains(searchText)
                    || kind.galleryDescription.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Widget")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredKinds) { kind in
                        galleryRow(kind)
                    }
                }
                .padding()
            }
        }
        .frame(width: 320, height: 420)
        .searchable(text: $searchText, prompt: "Search widgets")
    }

    private func galleryRow(_ kind: DashboardWidgetKind) -> some View {
        let placed = store.isKindPlaced(kind)

        return Button {
            if store.addWidget(kind, toRow: targetRowID) {
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kind.galleryIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(placed ? Color.secondary : Color.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(placed ? 0.04 : 0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(placed ? .secondary : .primary)
                    Text(placed ? "Already added" : kind.galleryDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if !placed {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(placed)
    }
}
