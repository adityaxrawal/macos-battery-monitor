// SettingsView.swift
// User-configurable thresholds, check interval, notification toggles,
// launch-at-login, and notification permission — all persisted automatically.

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var manager: MonitorManager
    @Environment(\.dismiss)  private var dismiss

    var isPopover: Bool = false
    var onBack: (() -> Void)? = nil

    private let intervalOptions = [1, 2, 5, 10, 15]
    @State private var powerMode: Int = 0

    var body: some View {
        ZStack {
            Color(hue: 0.65, saturation: 0.20, brightness: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Settings")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Thresholds, intervals & notifications")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Spacer()

                    if isPopover, let onBack = onBack {
                        Button(action: onBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Back")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disableFocusEffect()
                        .focusable(false)
                        .onHover { inside in
                            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    } else if !isPopover {
                        // Gear icon pill — decorative accent
                        HStack(spacing: 5) {
                            Image(systemName: "gearshape.2.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Configure")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.purple.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.purple.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.purple.opacity(0.3), lineWidth: 0.5))
                    }
                }
                .padding(.horizontal, isPopover ? 22 : 28)
                .padding(.top, isPopover ? 16 : 28)
                .padding(.bottom, isPopover ? 8 : 20)

                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
                    .padding(.horizontal, isPopover ? 24 : 22)

                ScrollView {
                    VStack(spacing: isPopover ? 14 : 18) {

                        // ── Notification permission status ──────────
                        notificationPermissionSection

                        // ── Thresholds ─────────────────────────────
                        SettingsSection(title: "Alert Thresholds") {
                            VStack(spacing: 14) {
                                ThresholdSlider(
                                    label:    "Critical Alert",
                                    icon:     "exclamationmark.triangle.fill",
                                    tint:     .red,
                                    value:    $manager.criticalThreshold,
                                    range:    5...20,
                                    unit:     "%"
                                )
                                settingsDivider
                                ThresholdSlider(
                                    label:    "Low Battery Alert",
                                    icon:     "battery.25percent",
                                    tint:     .orange,
                                    value:    $manager.lowThreshold,
                                    range:    15...50,
                                    unit:     "%"
                                )
                                settingsDivider
                                ThresholdSlider(
                                    label:    "Unplug Reminder",
                                    icon:     "bolt.fill",
                                    tint:     .mint,
                                    value:    $manager.highThreshold,
                                    range:    75...98,
                                    unit:     "%"
                                )
                            }
                        }

                        // ── Check interval ─────────────────────────
                        SettingsSection(title: "Check Interval") {
                            HStack(spacing: 8) {
                                ForEach(intervalOptions, id: \.self) { min in
                                    IntervalChip(
                                        label:    min == 1 ? "1m" : "\(min)m",
                                        selected: manager.checkIntervalMinutes == min
                                    ) {
                                        manager.checkIntervalMinutes = min
                                    }
                                }
                            }
                        }

                        // ── Notifications ──────────────────────────
                        SettingsSection(title: "Notification Alerts") {
                            VStack(spacing: 10) {
                                NotifToggle(
                                    icon:  "exclamationmark.triangle.fill",
                                    tint:  .red,
                                    label: "Critical battery (≤ \(manager.criticalThreshold)%)",
                                    value: $manager.notifyCritical
                                )
                                NotifToggle(
                                    icon:  "battery.25percent",
                                    tint:  .orange,
                                    label: "Low battery (≤ \(manager.lowThreshold)%)",
                                    value: $manager.notifyLow
                                )
                                NotifToggle(
                                    icon:  "bolt.fill",
                                    tint:  .mint,
                                    label: "Unplug reminder (≥ \(manager.highThreshold)%)",
                                    value: $manager.notifyHigh
                                )
                                NotifToggle(
                                    icon:  "powerplug.fill",
                                    tint:  .yellow,
                                    label: "Draining while plugged in",
                                    value: $manager.notifyDrainOnAC
                                )
                            }
                        }

                        // ── System ─────────────────────────────────
                        SettingsSection(title: "System") {
                            VStack(spacing: 14) {
                                HStack {
                                    Label("Launch at Login", systemImage: "arrow.up.right.square")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.8))
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { manager.launchAtLogin },
                                        set: { manager.setLaunchAtLogin($0) }
                                    ))
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    .disableFocusEffect()
                                    .focusable(false)
                                }
                                settingsDivider
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Label("Battery Power Mode", systemImage: "leaf.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.white.opacity(0.8))
                                        Text("Requires Touch ID / Password.")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { powerMode },
                                        set: { newValue in
                                            let oldMode = powerMode
                                            powerMode = newValue
                                            setPowerMode(newValue, revert: { powerMode = oldMode })
                                        }
                                    )) {
                                        Text("Automatic").tag(0)
                                        Text("Low Power").tag(1)
                                        Text("High Power").tag(2)
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .frame(width: 100)
                                    .disableFocusEffect()
                                    .focusable(false)
                                }
                            }
                        }

                        // ── Reset ──────────────────────────────────
                        Button {
                            withAnimation { manager.resetToDefaults() }
                        } label: {
                            Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.40))
                        }
                        .buttonStyle(.plain)
                        .disableFocusEffect()
                        .focusable(false)
                        .padding(.bottom, 8)
                    }
                    .padding(.horizontal, isPopover ? 22 : 28)
                    .padding(.top, isPopover ? 14 : 18)
                    .padding(.bottom, isPopover ? 14 : 28)
                }
            }
        }
        .frame(minWidth: isPopover ? 300 : 380, maxWidth: .infinity, minHeight: isPopover ? 300 : 580, maxHeight: .infinity)
        .onAppear {
            Task {
                powerMode = await getPowerMode()
            }
        }
    }

    // ── Notification permission status card ──────────────────────
    @ViewBuilder
    private var notificationPermissionSection: some View {
        let status = manager.notificationAuthStatus

        if status != .authorized {
            Button(action: {
                if status == .notDetermined {
                    Task { await manager.requestNotificationPermission() }
                } else {
                    // .denied — open System Settings
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(status == .denied
                             ? "Notifications Blocked"
                             : "Notifications Off")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(status == .denied
                             ? "Tap to open System Settings"
                             : "Tap to enable notifications")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .disableFocusEffect()
            .focusable(false)
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
    }

    private func getPowerMode() async -> Int {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
                task.arguments = ["-g"]
                let pipe = Pipe()
                task.standardOutput = pipe
                try? task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if let line = output.split(separator: "\n").first(where: { $0.contains("powermode") }) {
                    if line.contains("1") { continuation.resume(returning: 1); return }
                    if line.contains("2") { continuation.resume(returning: 2); return }
                }
                continuation.resume(returning: 0)
            }
        }
    }

    private func setPowerMode(_ mode: Int, revert: @escaping () -> Void) {
        guard (0...2).contains(mode) else { revert(); return }
        let source = "do shell script \"pmset -a powermode \(mode)\" with administrator privileges"
        var error: NSDictionary?
        if let script = NSAppleScript(source: source) {
            script.executeAndReturnError(&error)
            if error != nil {
                revert()
            }
        } else {
            revert()
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: – Sub-components
// ─────────────────────────────────────────────────

private struct SettingsSection<Content: View>: View {
    let title:   String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
                .tracking(1.2)
            content()
                .padding(14)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct ThresholdSlider: View {
    let label:  String
    let icon:   String
    let tint:   Color
    @Binding var value: Int
    let range:  ClosedRange<Int>
    let unit:   String

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(value)\(unit)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .frame(width: 36, alignment: .trailing)
            }
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
            .tint(tint)
        }
    }
}

private struct IntervalChip: View {
    let label:    String
    let selected: Bool
    let action:   () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? .white : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(selected ? Color.purple.opacity(0.7) : Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .disableFocusEffect()
        .focusable(false)
    }
}

private struct NotifToggle: View {
    let icon:  String
    let tint:  Color
    let label: String
    @Binding var value: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
            Toggle("", isOn: $value)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .disableFocusEffect()
                .focusable(false)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(MonitorManager.shared)
}
