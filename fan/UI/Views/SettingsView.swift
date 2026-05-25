import SwiftUI

// MARK: - Status bar display options

enum StatusBarDisplayMode: String, CaseIterable {
    case none = "None"
    case temperature = "Temperature"
    case power = "Power Usage"
    case fanSpeedPercentage = "Fan Speed %"

    var description: String { rawValue }
}

// MARK: - Navigation

private enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general = "General"
    case menuBar = "Menu Bar"
    case monitoring = "Monitoring"
    case alerts = "Alerts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .menuBar: return "menubar.rectangle"
        case .monitoring: return "waveform.path.ecg"
        case .alerts: return "bell.badge.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Startup and menu bar visibility"
        case .menuBar: return "Status item label"
        case .monitoring: return "Polling and automatic control"
        case .alerts: return "Temperature notifications"
        }
    }
}

// MARK: - Liquid Glass settings (reference-aligned)

/// Settings shell following [Liquid Glass Reference](https://github.com/conorluddy/LiquidGlassReference):
/// - **Content layer**: Form sections, no glass on lists/tables
/// - **Navigation layer**: system floating sidebar + glass toolbar controls
/// - **Backdrop**: mesh gradient for glass to refract (not on content)
private struct LiquidGlassSettingsView: View {
    @ObservedObject var viewModel: FanControlViewModel
    var presentation: SettingsPresentation

    @Environment(\.dismiss) private var dismiss
    @State private var selection: SettingsTab? = .general

    @State private var launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
    @State private var statusBarDisplayMode = UserDefaults.standard.string(forKey: "statusBarDisplayMode") ?? "temperature"
    @State private var monitoringInterval = UserDefaults.standard.double(forKey: "monitoringInterval") > 0
        ? UserDefaults.standard.double(forKey: "monitoringInterval") : 1.0
    @State private var enableNotifications = UserDefaults.standard.object(forKey: "enableNotifications") as? Bool ?? true
    @State private var highTempAlert = UserDefaults.standard.double(forKey: "highTempAlert") > 0
        ? UserDefaults.standard.double(forKey: "highTempAlert") : 85.0
    @State private var autoSwitchMode = UserDefaults.standard.bool(forKey: "autoSwitchMode")
    @State private var showMenuBarIcon = !MenuBarIconPreferences.isHidden

    enum SettingsPresentation {
        case window
        case sheet
    }

    var body: some View {
        ZStack {
            LiquidGlassAmbientBackground()

            NavigationSplitView {
                sidebar
            } detail: {
                detailColumn
            }
            .navigationSplitViewStyle(.balanced)
        }
        .frame(
            minWidth: presentation == .sheet ? 640 : 860,
            minHeight: presentation == .sheet ? 520 : 580
        )
        .onAppear {
            showMenuBarIcon = !MenuBarIconPreferences.isHidden
            if selection == nil { selection = .general }
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuBarIconVisibilityChanged)) { notification in
            if let hidden = notification.object as? Bool {
                showMenuBarIcon = !hidden
            }
        }
    }

    // MARK: Sidebar (navigation layer — system glass)

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                ForEach(SettingsTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tab.rawValue)
                                Text(tab.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        } icon: {
                            Image(systemName: tab.icon)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                    .tag(tab)
                }
            } header: {
                HStack(spacing: 10) {
                    Image(systemName: "fan.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.blue.gradient, in: Circle())
                    VStack(alignment: .leading, spacing: 0) {
                        Text("SoloFan")
                            .font(.headline)
                        Text("Settings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("SoloFan")
    }

    // MARK: Detail (content layer — no glass)

    @ViewBuilder
    private var detailColumn: some View {
        if let tab = selection {
            NavigationStack {
                Form {
                    switch tab {
                    case .general:
                        generalForm
                    case .menuBar:
                        menuBarForm
                    case .monitoring:
                        monitoringForm
                    case .alerts:
                        alertsForm
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .navigationTitle(tab.rawValue)
                .navigationSubtitle(tab.subtitle)
                .toolbar { detailToolbar }
            }
        } else {
            ContentUnavailableView(
                "Select a Category",
                systemImage: "gearshape",
                description: Text("Choose a settings category in the sidebar.")
            )
            .scrollContentBackground(.hidden)
        }
    }

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        if presentation == .sheet {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .buttonStyle(.glassProminent)
            }
        }
    }

    // MARK: Forms (plain content — never .glassEffect on rows)

    @ViewBuilder
    private var generalForm: some View {
        Section {
            Toggle(isOn: $showMenuBarIcon) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show menu bar icon")
                    Text(showMenuBarIcon
                        ? "SoloFan stays in the menu bar"
                        : "Hidden — reopen from Applications to access settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: showMenuBarIcon) { _, visible in
                AppDelegate.shared?.setMenuBarIconVisible(visible)
            }
        } header: {
            Text("Appearance")
        }

        Section {
            Toggle(isOn: $launchAtLogin) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at login")
                    Text("Start SoloFan when you sign in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: launchAtLogin) { _, enabled in
                UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
                viewModel.launchAtLogin = enabled
                LaunchAtLoginManager.shared.isEnabled = enabled
            }
        } header: {
            Text("Startup")
        }
    }

    @ViewBuilder
    private var menuBarForm: some View {
        Section {
            Picker(selection: $statusBarDisplayMode) {
                Label("Icon only", systemImage: "circle.slash").tag("none")
                Label("Temperature", systemImage: "thermometer.medium").tag("temperature")
                Label("Power usage", systemImage: "bolt.fill").tag("power")
                Label("Fan speed %", systemImage: "gauge.with.dots.needle.67percent").tag("fanSpeedPercentage")
            } label: {
                Text("Display")
            }
            .pickerStyle(.inline)
            .onChange(of: statusBarDisplayMode) { _, tag in
                UserDefaults.standard.set(tag, forKey: "statusBarDisplayMode")
                viewModel.statusBarDisplayMode = tag
                NotificationCenter.default.post(
                    name: NSNotification.Name("StatusBarDisplayModeChanged"),
                    object: tag
                )
            }
        } header: {
            Text("Menu Bar Label")
        } footer: {
            Text("On desktop Macs without a battery, power mode shows fan load or temperature.")
        }
    }

    @ViewBuilder
    private var monitoringForm: some View {
        Section {
            LabeledContent("Interval") {
                Text(String(format: "%.1f s", monitoringInterval))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $monitoringInterval, in: 0.5...5.0, step: 0.5)
                .onChange(of: monitoringInterval) { _, value in
                    UserDefaults.standard.set(value, forKey: "monitoringInterval")
                }
        } header: {
            Text("Refresh Rate")
        }

        Section {
            Toggle(isOn: $autoSwitchMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-switch mode")
                    Text("Enable automatic fan control when temperature spikes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: autoSwitchMode) { _, enabled in
                UserDefaults.standard.set(enabled, forKey: "autoSwitchMode")
            }
        } header: {
            Text("Automatic Control")
        }
    }

    @ViewBuilder
    private var alertsForm: some View {
        Section {
            Toggle(isOn: $enableNotifications) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable alerts")
                    Text("System notification when temperatures are high")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: enableNotifications) { _, enabled in
                UserDefaults.standard.set(enabled, forKey: "enableNotifications")
            }
        } header: {
            Text("Notifications")
        }

        Section {
            LabeledContent("Threshold") {
                Text(String(format: "%.0f °C", highTempAlert))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $highTempAlert, in: 70...95, step: 1)
                .onChange(of: highTempAlert) { _, value in
                    UserDefaults.standard.set(value, forKey: "highTempAlert")
                }
        } header: {
            Text("Alert Threshold")
        }
    }
}

// MARK: - Public entry points

struct SettingsView: View {
    @ObservedObject var viewModel: FanControlViewModel

    var body: some View {
        LiquidGlassSettingsView(viewModel: viewModel, presentation: .sheet)
    }
}

struct SettingsWindowView: View {
    @Binding var isOpen: Bool
    @ObservedObject var viewModel: FanControlViewModel

    var body: some View {
        LiquidGlassSettingsView(viewModel: viewModel, presentation: .window)
            .onAppear {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
    }
}
