//
//  DashboardStore.swift
//  SoloFan
//
//  Persists and mutates the popover widget dashboard layout.
//

import Combine
import Foundation
import SwiftUI

/// Observable store for the popover widget dashboard; persists to UserDefaults.
final class DashboardStore: ObservableObject {
    static let shared = DashboardStore()

    private static let storageKey = "dashboardLayout"

    @Published private(set) var layout: DashboardLayout

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? decoder.decode(DashboardLayout.self, from: data) {
            layout = saved
        } else {
            layout = Self.defaultLayout(hasBattery: BatteryMonitor.shared.hasBattery)
        }
    }

  // MARK: - Default layout

    /// Builds the initial layout matching the pre-v1.6 popover structure.
    static func defaultLayout(hasBattery: Bool) -> DashboardLayout {
        var rows: [DashboardRow] = []

        if hasBattery {
            rows.append(DashboardRow(columns: 2, widgets: [
                DashboardWidget(kind: .cpuTemperature),
                DashboardWidget(kind: .powerOrSystem)
            ]))
        } else {
            rows.append(DashboardRow(columns: 2, widgets: [
                DashboardWidget(kind: .cpuTemperature),
                DashboardWidget(kind: .gpuTemperature)
            ]))
        }

        rows.append(DashboardRow(columns: 1, widgets: [
            DashboardWidget(kind: .fanControl, columnSpan: 2)
        ]))

        rows.append(DashboardRow(columns: 1, widgets: [
            DashboardWidget(kind: .autoModeSettings, columnSpan: 2)
        ]))

        if hasBattery {
            rows.append(DashboardRow(columns: 1, widgets: [
                DashboardWidget(kind: .batteryInfo, columnSpan: 2)
            ]))
        }

        rows.append(DashboardRow(columns: 1, widgets: [
            DashboardWidget(kind: .systemInfo, columnSpan: 2)
        ]))

        return DashboardLayout(rows: rows)
    }

    /// Resets to factory defaults (e.g. after battery profile change).
    func resetToDefaults(hasBattery: Bool) {
        layout = Self.defaultLayout(hasBattery: hasBattery)
        persist()
    }

  // MARK: - Persistence

    private func persist() {
        guard let data = try? encoder.encode(layout) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

  // MARK: - Row operations

    func addRow(columns: Int = 2) {
        layout.rows.append(DashboardRow(columns: columns))
        persist()
    }

    func removeRow(id: UUID) {
        layout.rows.removeAll { $0.id == id }
        pruneEmptyRows()
        persist()
    }

    func setRowColumns(rowID: UUID, columns: Int) {
        guard let index = layout.rows.firstIndex(where: { $0.id == rowID }) else { return }
        layout.rows[index].columns = min(2, max(1, columns))
        normalizeRow(at: index)
        persist()
    }

  // MARK: - Widget operations

    /// Returns false if the kind is already placed or the row cannot fit the widget.
    @discardableResult
    func addWidget(_ kind: DashboardWidgetKind, toRow rowID: UUID) -> Bool {
        guard !layout.placedKinds.contains(kind) else { return false }
        guard let index = layout.rows.firstIndex(where: { $0.id == rowID }) else { return false }

        let widget = DashboardWidget(kind: kind)
        let row = layout.rows[index]
        let used = row.widgets.reduce(0) { $0 + $1.columnSpan }
        guard used + widget.columnSpan <= row.columns else { return false }

        layout.rows[index].widgets.append(widget)
        persist()
        return true
    }

    func removeWidget(id: UUID) {
        for rowIndex in layout.rows.indices {
            layout.rows[rowIndex].widgets.removeAll { $0.id == id }
        }
        pruneEmptyRows()
        persist()
    }

    /// Removes every widget of the given kind (e.g. battery on desktop Macs).
    func removeWidgets(ofKind kind: DashboardWidgetKind) {
        for rowIndex in layout.rows.indices {
            layout.rows[rowIndex].widgets.removeAll { $0.kind == kind }
        }
        pruneEmptyRows()
        persist()
    }

    func moveWidget(from source: IndexSet, to destination: Int, inRow rowID: UUID) {
        guard let index = layout.rows.firstIndex(where: { $0.id == rowID }) else { return }
        var widgets = layout.rows[index].widgets
        widgets.move(fromOffsets: source, toOffset: destination)
        layout.rows[index].widgets = widgets
        persist()
    }

    /// Moves a widget to the slot described by `DropSlotID` (insert-before semantics).
    func applyDrop(widgetID: UUID, to slot: DropSlotID) {
        guard let (sourceRowIndex, sourceWidgetIndex, widget) = locateWidget(id: widgetID) else { return }

        if layout.rows[sourceRowIndex].id == slot.rowID {
            var widgets = layout.rows[sourceRowIndex].widgets
            let item = widgets.remove(at: sourceWidgetIndex)
            var dest = min(max(0, slot.index), widgets.count + 1)
            if sourceWidgetIndex < dest { dest -= 1 }
            dest = min(max(0, dest), widgets.count)
            widgets.insert(item, at: dest)
            layout.rows[sourceRowIndex].widgets = widgets
        } else {
            var moving = widget
            layout.rows[sourceRowIndex].widgets.remove(at: sourceWidgetIndex)

            guard let targetRowIndex = layout.rows.firstIndex(where: { $0.id == slot.rowID }) else {
                layout.rows[sourceRowIndex].widgets.insert(moving, at: sourceWidgetIndex)
                return
            }

            let used = layout.rows[targetRowIndex].widgets.reduce(0) { $0 + $1.columnSpan }
            if used + moving.columnSpan > layout.rows[targetRowIndex].columns {
                moving.columnSpan = min(moving.columnSpan, layout.rows[targetRowIndex].columns)
            }

            let insertAt = min(max(0, slot.index), layout.rows[targetRowIndex].widgets.count)
            layout.rows[targetRowIndex].widgets.insert(moving, at: insertAt)
            pruneEmptyRows()
        }

        persist()
    }

    /// Moves a widget from one row to another at the given index.
    func moveWidget(widgetID: UUID, toRow targetRowID: UUID, at index: Int) {
        applyDrop(widgetID: widgetID, to: DropSlotID(rowID: targetRowID, index: index))
    }

    /// Reorders a widget within the same row.
    func reorderWidget(widgetID: UUID, inRow rowID: UUID, toIndex index: Int) {
        applyDrop(widgetID: widgetID, to: DropSlotID(rowID: rowID, index: index))
    }

    func setColumnSpan(widgetID: UUID, span: Int) {
        for rowIndex in layout.rows.indices {
            if let widgetIndex = layout.rows[rowIndex].widgets.firstIndex(where: { $0.id == widgetID }) {
                layout.rows[rowIndex].widgets[widgetIndex].columnSpan = min(2, max(1, span))
                normalizeRow(at: rowIndex)
                persist()
                return
            }
        }
    }

    func isKindPlaced(_ kind: DashboardWidgetKind) -> Bool {
        layout.placedKinds.contains(kind)
    }

  // MARK: - Helpers

    private func findWidget(id: UUID) -> DashboardWidget? {
        locateWidget(id: id)?.2
    }

    private func locateWidget(id: UUID) -> (rowIndex: Int, widgetIndex: Int, widget: DashboardWidget)? {
        for (ri, row) in layout.rows.enumerated() {
            if let wi = row.widgets.firstIndex(where: { $0.id == id }) {
                return (ri, wi, row.widgets[wi])
            }
        }
        return nil
    }

    private func pruneEmptyRows() {
        layout.rows.removeAll { $0.widgets.isEmpty }
    }

    /// Ensures widgets fit within the row's column budget.
    private func normalizeRow(at index: Int) {
        let maxCols = layout.rows[index].columns
        for i in layout.rows[index].widgets.indices {
            layout.rows[index].widgets[i].columnSpan = min(layout.rows[index].widgets[i].columnSpan, maxCols)
        }
    }
}
