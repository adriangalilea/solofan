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

    var tint: Color {
        switch self {
        case .general: return .blue
        case .menuBar: return .cyan
        case .monitoring: return .mint
        case .alerts: return .orange
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Startup & visibility"
        case .menuBar: return "Status item display"
        case .monitoring: return "Polling & auto control"
        case .alerts: return "Temperature warnings"
        }
    }
}

// MARK: - Plain grouped section (content layer — no glass)

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Settings shell (NavigationSplitView + glass nav only)

private struct LiquidGlassSettingsView: View {
    @ObservedObject var viewModel: FanControlViewModel
    var presentation: SettingsPresentation

    @Environment(\.dismiss) private var dismiss
    @Namespace private var glassNamespace
    @State private var selection: SettingsTab = .general

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
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            detailPane
        }
        .background {
            LiquidGlassAmbientBackground()
        }
        .frame(
            minWidth: presentation == .sheet ? 620 : 820,
            minHeight: presentation == .sheet ? 520 : 560
        )
        .onAppear {
            showMenuBarIcon = !MenuBarIconPreferences.isHidden
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuBarIconVisibilityChanged)) { notification in
            if let hidden = notification.object as? Bool {
                showMenuBarIcon = !hidden
            }
        }
    }

    // MARK: Sidebar (navigation layer — glass)

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "fan.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.blue.opacity(0.55), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("SoloFan")
                        .font(.title3.weight(.bold))
                    Text("Settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            GlassEffectContainer(spacing: 6) {
                VStack(spacing: 4) {
                    ForEach(SettingsTab.allCases) { tab in
                        sidebarTabButton(tab)
                    }
                }
            }

            Spacer(minLength: 0)

            if presentation == .sheet {
                Button("Done") { dismiss() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 12)
    }

    private func sidebarTabButton(_ tab: SettingsTab) -> some View {
        let isSelected = selection == tab

        return Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                selection = tab
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? tab.tint : .secondary)
                    .frame(width: 22)

                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected
                ? .regular.tint(tab.tint.opacity(0.2)).interactive()
                : .clear.interactive(),
            in: .rect(cornerRadius: 12)
        )
        .glassEffectID(tab.id, in: glassNamespace)
        .padding(.horizontal, 8)
    }

    // MARK: Detail (content layer — no glass)

    private var detailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selection.rawValue)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(selection.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                detailContent
            }
            .padding(24)
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .general:
            generalSections
        case .menuBar:
            menuBarSections
        case .monitoring:
            monitoringSections
        case .alerts:
            alertsSections
        }
    }

    // MARK: Content sections

    private var generalSections: some View {
        VStack(spacing: 16) {
            SettingsSection(title: "Appearance", icon: "eye.fill", tint: .blue) {
                settingsToggle(
                    title: "Show menu bar icon",
                    subtitle: showMenuBarIcon
                        ? "SoloFan stays in the menu bar"
                        : "Hidden — reopen SoloFan from Applications to access settings",
                    isOn: $showMenuBarIcon
                ) { visible in
                    AppDelegate.shared?.setMenuBarIconVisible(visible)
                }
            }

            SettingsSection(title: "Startup", icon: "power.circle.fill", tint: .purple) {
                settingsToggle(
                    title: "Launch at login",
                    subtitle: "Start SoloFan when you sign in",
                    isOn: $launchAtLogin
                ) { enabled in
                    UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
                    viewModel.launchAtLogin = enabled
                    LaunchAtLoginManager.shared.isEnabled = enabled
                }
            }
        }
    }

    private var menuBarSections: some View {
        SettingsSection(title: "Menu bar label", icon: "textformat.123", tint: .cyan) {
            VStack(spacing: 4) {
                menuBarOption("none", label: "Icon only", icon: "circle.slash")
                menuBarOption("temperature", label: "Temperature", icon: "thermometer.medium")
                menuBarOption("power", label: "Power usage", icon: "bolt.fill")
                menuBarOption("fanSpeedPercentage", label: "Fan speed %", icon: "gauge.with.dots.needle.67percent")
            }
        }
    }

    private func menuBarOption(_ tag: String, label: String, icon: String) -> some View {
        let selected = statusBarDisplayMode == tag

        return Button {
            statusBarDisplayMode = tag
            UserDefaults.standard.set(tag, forKey: "statusBarDisplayMode")
            viewModel.statusBarDisplayMode = tag
            NotificationCenter.default.post(
                name: NSNotification.Name("StatusBarDisplayModeChanged"),
                object: tag
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? .cyan : .secondary)
                    .frame(width: 22)

                Text(label)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))

                Spacer()

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(selected ? Color.cyan.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var monitoringSections: some View {
        SettingsSection(title: "Refresh & control", icon: "timer", tint: .mint) {
            settingsSlider(
                title: "Monitoring interval",
                value: $monitoringInterval,
                range: 0.5...5.0,
                step: 0.5,
                format: { String(format: "%.1f s", $0) }
            ) { value in
                UserDefaults.standard.set(value, forKey: "monitoringInterval")
            }

            Divider().opacity(0.3)

            settingsToggle(
                title: "Auto-switch mode",
                subtitle: "Enable automatic fan control when temperature spikes",
                isOn: $autoSwitchMode
            ) { enabled in
                UserDefaults.standard.set(enabled, forKey: "autoSwitchMode")
            }
        }
    }

    private var alertsSections: some View {
        SettingsSection(title: "Notifications", icon: "bell.fill", tint: .orange) {
            settingsToggle(
                title: "Enable alerts",
                subtitle: "System notification when temps are high",
                isOn: $enableNotifications
            ) { enabled in
                UserDefaults.standard.set(enabled, forKey: "enableNotifications")
            }

            Divider().opacity(0.3)

            settingsSlider(
                title: "Alert threshold",
                value: $highTempAlert,
                range: 70...95,
                step: 1,
                format: { String(format: "%.0f °C", $0) }
            ) { value in
                UserDefaults.standard.set(value, forKey: "highTempAlert")
            }
        }
    }

    // MARK: Row builders

    private func settingsToggle(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .onChange(of: isOn.wrappedValue) { _, value in
                    onChange(value)
                }
        }
    }

    private func settingsSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: (Double) -> String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: value, in: range, step: step)
                .onChange(of: value.wrappedValue) { _, v in
                    onChange(v)
                }
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
