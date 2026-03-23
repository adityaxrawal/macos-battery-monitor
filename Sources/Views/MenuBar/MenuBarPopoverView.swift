// MenuBarPopoverView.swift
// Popover shown when user clicks the menu bar icon.
// Refined premium dark UI with glassmorphism, glow effects, and no focus rings.

import SwiftUI

// ─────────────────────────────────────────────────
// MARK: – Root Popover View
// ─────────────────────────────────────────────────

struct MenuBarPopoverView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var manager: MonitorManager

    var info: BatteryInfo { manager.batteryInfo }

    var body: some View {
        VStack(spacing: 0) {
            mainPopoverContent
        }
        .frame(width: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var mainPopoverContent: some View {
        VStack(spacing: 0) {
            // ── Top section: gauge + live data ────────────────────
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color(hue: 0.62, saturation: 0.20, brightness: 0.14),
                        Color(hue: 0.65, saturation: 0.25, brightness: 0.09)
                    ],
                    startPoint: .topLeading,
                    endPoint:   .bottomTrailing
                )

                VStack(spacing: 16) {
                    // Battery gauge ring
                    PopoverGaugeView(info: info)
                        .frame(width: 148, height: 148)

                    // Status chip
                    StatusChipView(info: info)
                        .padding(.bottom, 2)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)
            }

            popoverDivider

            // ── Quick Settings ─────────────────────────────────────
            QuickSettingsView()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(hue: 0.65, saturation: 0.20, brightness: 0.11))

            popoverDivider

            // ── Action strip ──────────────────────────────────────
            ActionStripView(
                isRunning:    manager.isRunning,
                onToggle: {
                    if manager.isRunning { manager.stop() } else { manager.start() }
                },
                onOpenApp: {
                    // 1. Activate the app to bring it to front
                    NSApp.activate(ignoringOtherApps: true)
                    
                    // 2. Try to find the existing "main" window to focus it instead of opening a new one
                    // SwiftUI WindowGroup windows usually have identifiers containing the ID we gave them
                    let existingWindow = NSApp.windows.first { window in
                        window.identifier?.rawValue.contains("main") == true
                    }
                    
                    if let window = existingWindow {
                        window.makeKeyAndOrderFront(nil)
                    } else {
                        // Only open a new window if one doesn't exist
                        openWindow(id: "main")
                    }
                    
                    // 3. We removed the NSApp.sendAction(#selector(NSPopover.performClose(_:)), ...) 
                    // which is often the source of the system feedback sound (beep/alert) 
                    // when triggered with a nil target from a MenuBarExtra context.
                }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(hue: 0.65, saturation: 0.16, brightness: 0.09))
        }
        .frame(width: 300)
    }

    private var popoverDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
    }
}

// ─────────────────────────────────────────────────
// MARK: – Battery Gauge Ring
// ─────────────────────────────────────────────────

private struct PopoverGaugeView: View {
    let info: BatteryInfo

    @State private var animatedProgress: Double = 0

    var progress: Double { Double(info.percentage) / 100.0 }

    var gaugeColor: Color {
        if info.isPluggedIn && info.chargeStatus.isCharging { return .mint }
        switch info.percentage {
        case 0...10:  return Color(hue: 0.0,  saturation: 0.85, brightness: 0.9)
        case 11...30: return Color(hue: 0.08, saturation: 0.85, brightness: 0.95)
        default:      return Color(hue: 0.36, saturation: 0.72, brightness: 0.85)
        }
    }

    var body: some View {
        ZStack {
            // Glow halo
            Circle()
                .stroke(gaugeColor.opacity(0.07), lineWidth: 24)

            // Track ring
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 11)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [gaugeColor.opacity(0.55), gaugeColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle:   .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: gaugeColor.opacity(0.45), radius: 6)
                .animation(.spring(response: 1.0, dampingFraction: 0.7), value: animatedProgress)

            // Center content
            VStack(spacing: 2) {
                if info.isPluggedIn && info.chargeStatus.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.mint)
                }
                Text("\(info.percentage)%")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(info.chargeStatus.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: info.percentage) { _ in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: – Quick Settings Section
// ─────────────────────────────────────────────────

private struct QuickSettingsView: View {
    @EnvironmentObject var manager: MonitorManager

    var body: some View {
        VStack(spacing: 12) {
            SettingSlider(
                label: "Critical Alert",
                icon: "exclamationmark.triangle.fill",
                tint: .red,
                value: $manager.criticalThreshold,
                range: 5...20
            )
            SettingSlider(
                label: "Low Battery",
                icon: "battery.25percent",
                tint: .orange,
                value: $manager.lowThreshold,
                range: 15...50
            )
            SettingSlider(
                label: "Unplug Reminder",
                icon: "bolt.fill",
                tint: .mint,
                value: $manager.highThreshold,
                range: 75...98
            )
        }
    }
}

private struct SettingSlider: View {
    let label: String
    let icon:  String
    let tint:  Color
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Label {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                } icon: {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(tint)
                }
                Spacer()
                Text("\(value)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
            .tint(tint)
            .controlSize(.small)
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: – Status Chip
// ─────────────────────────────────────────────────

private struct StatusChipView: View {
    let info: BatteryInfo

    var chipColor: Color {
        if info.isPluggedIn && info.chargeStatus.isCharging { return .mint }
        if info.isCritical  { return .red   }
        if info.isLow       { return .orange }
        return Color(hue: 0.36, saturation: 0.65, brightness: 0.8)
    }

    var icon: String {
        if info.chargeStatus == .charged     { return "checkmark.circle.fill" }
        if info.isPluggedIn                  { return "bolt.fill" }
        if info.isCritical                   { return "exclamationmark.triangle.fill" }
        return "clock.fill"
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(info.timeRemainingString)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(chipColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(chipColor.opacity(0.13))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(chipColor.opacity(0.3), lineWidth: 0.5))
    }
}



// ─────────────────────────────────────────────────
// MARK: – Action Strip
// ─────────────────────────────────────────────────

private struct ActionStripView: View {
    let isRunning:    Bool
    let onToggle:   () -> Void
    let onOpenApp:  () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Monitor toggle
            Button(action: onToggle) {
                HStack(spacing: 5) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(isRunning ? "Pause" : "Monitor")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(isRunning ? .orange : .mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((isRunning ? Color.orange : Color.mint).opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((isRunning ? Color.orange : Color.mint).opacity(0.28), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .disableFocusEffect()
            .focusable(false)
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }

            Spacer()

            // Open full app window
            ActionIconButton(icon: "arrow.up.left.and.arrow.down.right", action: onOpenApp)

            // Quit
            ActionIconButton(icon: "xmark.circle.fill", tint: Color.red.opacity(0.6)) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

private struct ActionIconButton: View {
    let icon:   String
    var tint:   Color = Color.white.opacity(0.45)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(tint)
                .frame(width: 27, height: 27)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .disableFocusEffect()
        .focusable(false)
        .onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: – Preview
// ─────────────────────────────────────────────────

#Preview {
    MenuBarPopoverView()
        .environmentObject(MonitorManager.shared)
}
