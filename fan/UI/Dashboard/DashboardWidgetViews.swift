//
//  DashboardWidgetViews.swift
//  SoloFan
//
//  Extracted widget content views for the popover dashboard.
//

import SwiftUI

// MARK: - Temperature helpers

func dashboardTemperatureColor(_ temp: Double?) -> Color {
    guard let temp else { return .gray }
    if temp < 50 { return .blue }
    if temp < 70 { return .yellow }
    if temp < 85 { return .orange }
    return .red
}

// MARK: - Auto mode widget

struct AutoModeSettingsWidget: View {
    @ObservedObject var viewModel: FanControlViewModel

    private var aggressivenessLabel: String {
        let val = viewModel.autoAggressiveness
        if val <= 0.3 { return "Min Override" }
        if val <= 0.8 { return "Quiet" }
        if val <= 1.2 { return "Balanced" }
        if val <= 1.8 { return "Auto" }
        if val <= 2.3 { return "Performance" }
        if val <= 2.7 { return "Aggressive" }
        return "Max Override"
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("Threshold")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(String(format: "%.0f°C", viewModel.autoThreshold))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.orange)
            }

            Slider(
                value: Binding(
                    get: { viewModel.autoThreshold },
                    set: { viewModel.setAutoThreshold($0) }
                ),
                in: 40...90,
                step: 5
            )
            .accentColor(.orange)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text("Max Speed")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(viewModel.autoMaxSpeed) RPM")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
            }

            Slider(
                value: Binding(
                    get: { Double(viewModel.autoMaxSpeed) },
                    set: { viewModel.setAutoMaxSpeed(Int($0)) }
                ),
                in: Double(viewModel.effectiveUnifiedMinRPM)...Double(max(viewModel.effectiveUnifiedMaxRPM, viewModel.effectiveUnifiedMinRPM + 1)),
                step: 100
            )
            .accentColor(.blue)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "dial.medium")
                        .font(.system(size: 10))
                        .foregroundColor(.purple)
                    Text("Response")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(aggressivenessLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.purple)
            }

            Slider(
                value: Binding(
                    get: { viewModel.autoAggressiveness },
                    set: { viewModel.setAutoAggressiveness($0) }
                ),
                in: 0.0...3.0,
                step: 0.1
            )
            .accentColor(.purple)
        }
        .padding(12)
        .liquidGlass()
    }
}

// MARK: - Battery widget

struct BatteryInfoWidget: View {
    @ObservedObject var battery: BatteryMonitor

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: batteryIcon)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("Battery")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(battery.batteryInfo.percentage)%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.8))
            }

            Divider().opacity(0.5)

            VStack(spacing: 4) {
                HStack(spacing: 16) {
                    CompactInfoItem(label: "Health", value: "\(battery.batteryInfo.health)%")
                    CompactInfoItem(label: "Cycles", value: "\(battery.batteryInfo.cycleCount)")
                    CompactInfoItem(label: "Status", value: battery.batteryInfo.condition)
                }

                HStack(spacing: 16) {
                    if let temp = battery.batteryInfo.temperature {
                        CompactInfoItem(label: "Temp", value: String(format: "%.1f°", temp))
                    }
                    if let voltage = battery.batteryInfo.voltage {
                        CompactInfoItem(label: "Voltage", value: String(format: "%.2fV", voltage))
                    }
                    if let power = battery.batteryInfo.powerWatts, power > 0.1 {
                        CompactInfoItem(label: "Power", value: String(format: "%.1fW", power))
                    }
                }

                if let maxCap = battery.batteryInfo.maxCapacity,
                   let designCap = battery.batteryInfo.designCapacity {
                    HStack(spacing: 16) {
                        CompactInfoItem(label: "Capacity", value: "\(maxCap)/\(designCap)mAh")
                        CompactInfoItem(label: "Source", value: battery.batteryInfo.isPluggedIn ? "AC" : "Battery")
                        if let timeStr = battery.batteryInfo.formattedTimeRemaining {
                            CompactInfoItem(
                                label: battery.batteryInfo.isCharging ? "Full in" : "Left",
                                value: timeStr
                            )
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }

    private var batteryIcon: String {
        let pct = battery.batteryInfo.percentage
        if battery.batteryInfo.isCharging { return "battery.100.bolt" }
        if pct > 75 { return "battery.100" }
        if pct > 50 { return "battery.75" }
        if pct > 25 { return "battery.50" }
        return "battery.25"
    }
}

// MARK: - System info widget

struct SystemInfoWidget: View {
    @ObservedObject var viewModel: FanControlViewModel

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("System")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }

            Divider().opacity(0.5)

            VStack(spacing: 4) {
                HStack(spacing: 16) {
                    if let cpuTemp = viewModel.cpuTemperature {
                        CompactInfoItem(label: "CPU", value: String(format: "%.0f°", cpuTemp))
                    }
                    if let gpuTemp = viewModel.gpuTemperature {
                        CompactInfoItem(label: "GPU", value: String(format: "%.0f°", gpuTemp))
                    }
                    CompactInfoItem(label: "Fans", value: "\(viewModel.numberOfFans)")
                    CompactInfoItem(label: "RPM", value: "\(viewModel.currentFanSpeed)")
                }

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fan limits")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        ForEach(0..<viewModel.numberOfFans, id: \.self) { i in
                            Text("Fan \(i + 1): \(viewModel.minRPM(atFan: i))–\(viewModel.maxRPM(atFan: i)) RPM")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    CompactInfoItem(
                        label: "Mode",
                        value: viewModel.controlMode == .automatic ? "Auto" : "Manual"
                    )
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(8)
    }
}

// MARK: - Desktop system load card (no battery)

struct SystemLoadCardView: View {
  let fanPercent: Int
  let fanRPM: Int
  let gpuTemperature: Double?

  private var color: Color {
    if let gpu = gpuTemperature {
      return dashboardTemperatureColor(gpu)
    }
    if fanPercent > 70 { return .orange }
    if fanPercent > 40 { return .yellow }
    return .blue
  }

  private var statusText: String {
    if gpuTemperature != nil { return "GPU Temp" }
    return "Fan Load"
  }

  private var displayValue: String {
    if let gpu = gpuTemperature {
      return String(format: "%.0f", gpu)
    }
    return "\(fanPercent)"
  }

  private var unitText: String {
    gpuTemperature != nil ? "°" : "%"
  }

  var body: some View {
    VStack(spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: gpuTemperature != nil ? "gpu" : "gauge.with.dots.needle.67percent")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(color.opacity(0.8))

        Text(gpuTemperature != nil ? "GPU" : "System")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(.secondary)

        Spacer()

        Text(statusText)
          .font(.system(size: 9, weight: .medium))
          .foregroundColor(color)
      }

      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(displayValue)
          .font(.system(size: 32, weight: .bold, design: .rounded))
          .foregroundStyle(
            LinearGradient(
              colors: [color, color.opacity(0.7)],
              startPoint: .top,
              endPoint: .bottom
            )
          )

        Text(unitText)
          .font(.system(size: 20, weight: .medium))
          .foregroundColor(color.opacity(0.6))

        Spacer()
      }

      if gpuTemperature == nil {
        Text("\(fanRPM) RPM")
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(12)
    .liquidGlass()
  }
}

// MARK: - Widget router

struct DashboardWidgetView: View {
  let widget: DashboardWidget
  @ObservedObject var viewModel: FanControlViewModel
  @ObservedObject var battery: BatteryMonitor
  var isEditing: Bool = false

  var body: some View {
    Group {
      switch widget.kind {
      case .cpuTemperature:
        TemperatureView(
          label: "CPU",
          temperature: viewModel.cpuTemperature,
          color: dashboardTemperatureColor(viewModel.cpuTemperature)
        )
      case .gpuTemperature:
        TemperatureView(
          label: "GPU",
          temperature: viewModel.gpuTemperature,
          color: dashboardTemperatureColor(viewModel.gpuTemperature)
        )
      case .powerOrSystem:
        if battery.hasBattery {
          PowerCardView(
            powerWatts: battery.batteryInfo.powerWatts,
            isCharging: battery.batteryInfo.isCharging,
            isPluggedIn: battery.batteryInfo.isPluggedIn
          )
        } else {
          SystemLoadCardView(
            fanPercent: viewModel.averageFanLoadPercent,
            fanRPM: viewModel.currentFanSpeed,
            gpuTemperature: viewModel.gpuTemperature
          )
        }
      case .fanControl:
        FanSpeedView(viewModel: viewModel)
      case .autoModeSettings:
        if viewModel.controlMode == .automatic {
          AutoModeSettingsWidget(viewModel: viewModel)
        } else {
          EmptyView()
        }
      case .batteryInfo:
        if battery.hasBattery {
          BatteryInfoWidget(battery: battery)
        } else {
          EmptyView()
        }
      case .systemInfo:
        SystemInfoWidget(viewModel: viewModel)
      }
    }
    .allowsHitTesting(!isEditing)
  }
}
