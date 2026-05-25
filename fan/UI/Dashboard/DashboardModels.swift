//
//  DashboardModels.swift
//  SoloFan
//
//  Codable models for the popover widget dashboard layout.
//

import Foundation

/// Identifies a widget type shown in the popover dashboard.
enum DashboardWidgetKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case cpuTemperature
    case gpuTemperature
    case powerOrSystem
    case fanControl
    case autoModeSettings
    case batteryInfo
    case systemInfo

    var id: String { rawValue }

    /// Human-readable title for the widget gallery.
    var displayName: String {
        switch self {
        case .cpuTemperature: return "CPU Temperature"
        case .gpuTemperature: return "GPU Temperature"
        case .powerOrSystem: return "Power / System"
        case .fanControl: return "Fan Control"
        case .autoModeSettings: return "Auto Mode"
        case .batteryInfo: return "Battery"
        case .systemInfo: return "System Info"
        }
    }

    var galleryIcon: String {
        switch self {
        case .cpuTemperature: return "cpu"
        case .gpuTemperature: return "gpu"
        case .powerOrSystem: return "bolt.fill"
        case .fanControl: return "fan.fill"
        case .autoModeSettings: return "dial.medium"
        case .batteryInfo: return "battery.100"
        case .systemInfo: return "info.circle"
        }
    }

    var galleryDescription: String {
        switch self {
        case .cpuTemperature: return "Live CPU temperature card"
        case .gpuTemperature: return "Live GPU temperature card"
        case .powerOrSystem: return "Battery power or desktop system load"
        case .fanControl: return "Manual fan speed sliders"
        case .autoModeSettings: return "Threshold, max speed, response"
        case .batteryInfo: return "Health, cycles, capacity"
        case .systemInfo: return "Fans, RPM, limits, mode"
        }
    }

    /// Default column span when added to a row (1 = half width, 2 = full width).
    var defaultColumnSpan: Int {
        switch self {
        case .cpuTemperature, .gpuTemperature, .powerOrSystem:
            return 1
        case .fanControl, .autoModeSettings, .batteryInfo, .systemInfo:
            return 2
        }
    }

    /// Whether this widget is available on the current device profile.
    func isAvailable(hasBattery: Bool) -> Bool {
        switch self {
        case .batteryInfo:
            return hasBattery
        default:
            return true
        }
    }
}

/// A single placed widget in the dashboard grid.
struct DashboardWidget: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var kind: DashboardWidgetKind
    /// Number of columns this widget spans within its row (1 or 2).
    var columnSpan: Int

    init(id: UUID = UUID(), kind: DashboardWidgetKind, columnSpan: Int? = nil) {
        self.id = id
        self.kind = kind
        self.columnSpan = columnSpan ?? kind.defaultColumnSpan
    }
}

/// One horizontal row in the dashboard; widgets flow left-to-right up to `columns`.
struct DashboardRow: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    /// 1 = single column (full width widgets), 2 = two-column grid.
    var columns: Int
    var widgets: [DashboardWidget]

    init(id: UUID = UUID(), columns: Int = 2, widgets: [DashboardWidget] = []) {
        self.id = id
        self.columns = min(2, max(1, columns))
        self.widgets = widgets
    }
}

/// Full persisted dashboard layout.
struct DashboardLayout: Codable, Equatable {
    var rows: [DashboardRow]

    /// All widget kinds currently placed in the layout.
    var placedKinds: Set<DashboardWidgetKind> {
        Set(rows.flatMap { $0.widgets.map(\.kind) })
    }
}
