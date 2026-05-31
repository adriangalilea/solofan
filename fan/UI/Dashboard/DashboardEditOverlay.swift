//
//  DashboardEditOverlay.swift
//  SoloFan
//
//  Edit-mode chrome: drop zones, frame tracking.
//

import SwiftUI

// MARK: - Drop zone (always hittable in edit mode)

struct DashboardDropZone: View {
    let slot: DropSlotID
    let isActive: Bool

    private let minHitHeight: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(
                isActive ? Color.accentColor : Color.clear,
                style: StrokeStyle(lineWidth: 2, dash: [6, 4])
            )
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .frame(height: isActive ? 36 : minHitHeight)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isActive)
            .trackDropSlotFrame(slot: slot)
    }
}

// MARK: - Remove badge

struct WidgetRemoveBadge: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 20))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
        }
        .buttonStyle(.plain)
        .offset(x: 6, y: -6)
    }
}

// MARK: - Preference keys

struct WidgetFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, n in n }
    }
}

struct DropSlotFramePreferenceKey: PreferenceKey {
    static var defaultValue: [DropSlotID: CGRect] = [:]
    static func reduce(value: inout [DropSlotID: CGRect], nextValue: () -> [DropSlotID: CGRect]) {
        value.merge(nextValue()) { _, n in n }
    }
}

extension View {
    func trackWidgetFrame(id: UUID, in space: CoordinateSpace) -> some View {
        background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: WidgetFramePreferenceKey.self,
                    value: [id: geo.frame(in: space)]
                )
            }
        }
    }

    func trackDropSlotFrame(slot: DropSlotID, in space: CoordinateSpace = .named("dashboardGrid")) -> some View {
        background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: DropSlotFramePreferenceKey.self,
                    value: [slot: geo.frame(in: space)]
                )
            }
        }
    }
}
