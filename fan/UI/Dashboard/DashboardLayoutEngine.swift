//
//  DashboardLayoutEngine.swift
//  SoloFan
//
//  Pure layout math for the widget dashboard: row packing, drop targeting, reorder indices.
//

import CoreGraphics
import Foundation

// MARK: - Drop slot identity

struct DropSlotID: Hashable, Equatable {
    let rowID: UUID
    /// Insert before `row.widgets[index]`; `index == count` appends.
    let index: Int
}

// MARK: - Render segments

enum DashboardRowSegment: Identifiable, Equatable {
    case dropZone(index: Int)
    case widget(DashboardWidget)
    case pair(left: DashboardWidget, right: DashboardWidget)

    var id: String {
        switch self {
        case .dropZone(let index): return "drop-\(index)"
        case .widget(let w): return "w-\(w.id.uuidString)"
        case .pair(let left, let right): return "pair-\(left.id.uuidString)-\(right.id.uuidString)"
        }
    }
}

// MARK: - Layout engine

enum DashboardLayoutEngine {

    /// Finds the nearest drop slot for a pointer in dashboard coordinates.
    static func resolveDropSlot(
        at point: CGPoint,
        slotFrames: [DropSlotID: CGRect],
        excludingWidgetID: UUID,
        layout: DashboardLayout
    ) -> DropSlotID? {
        guard !slotFrames.isEmpty else { return nil }

        var best: (DropSlotID, CGFloat)?

        for (slot, frame) in slotFrames {
            guard layout.rows.contains(where: { $0.id == slot.rowID }) else { continue }
            if slotWouldDuplicate(slot, layout: layout, excluding: excludingWidgetID) { continue }

            let expanded = frame.insetBy(dx: -10, dy: -8)
            let distance = expanded.contains(point) ? 0 : distanceFrom(point, to: expanded)

            if best == nil || distance < best!.1 {
                best = (slot, distance)
            }
        }

        guard let candidate = best, candidate.1 < 72 else { return nil }
        return candidate.0
    }

    /// Whether dropping on this slot would leave the widget at the same index.
    static func isNoOpDrop(
        slot: DropSlotID,
        draggedWidgetID: UUID,
        sourceRowID: UUID,
        layout: DashboardLayout
    ) -> Bool {
        guard slot.rowID == sourceRowID,
              let row = layout.rows.first(where: { $0.id == slot.rowID }),
              let sourceIndex = row.widgets.firstIndex(where: { $0.id == draggedWidgetID })
        else { return false }

        var dest = slot.index
        if sourceIndex < dest { dest -= 1 }
        return dest == sourceIndex
    }

    /// Segments for rendering a row with 2-column packing and interleaved drop zones.
    static func renderSegments(for row: DashboardRow) -> [DashboardRowSegment] {
        var segments: [DashboardRowSegment] = []
        segments.append(.dropZone(index: 0))

        var index = 0
        while index < row.widgets.count {
            let widget = row.widgets[index]

            if row.columns == 2,
               widget.columnSpan == 1,
               index + 1 < row.widgets.count,
               row.widgets[index + 1].columnSpan == 1 {
                segments.append(.pair(left: widget, right: row.widgets[index + 1]))
                index += 2
                segments.append(.dropZone(index: index))
            } else {
                segments.append(.widget(widget))
                index += 1
                segments.append(.dropZone(index: index))
            }
        }

        return segments
    }

    // MARK: - Private

    private static func slotWouldDuplicate(
        _ slot: DropSlotID,
        layout: DashboardLayout,
        excluding widgetID: UUID
    ) -> Bool {
        guard let row = layout.rows.first(where: { $0.id == slot.rowID }) else { return true }
        let countWithoutDragged = row.widgets.filter { $0.id != widgetID }.count
        return slot.index > countWithoutDragged
    }

    private static func distanceFrom(_ point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }
}
