// MainAppView.swift
// Full-window premium app UI with sidebar navigation.
// Shown when user launches from Dock / Finder.
// Tabs: Overview, Health, Settings, About.

import SwiftUI

// ─────────────────────────────────────────────────
// MARK: – Tab enum
// ─────────────────────────────────────────────────

enum AppTab: String, CaseIterable {
    case overview = "Overview"
    case health   = "Health"
    case settings = "Settings"
    case about    = "About"

    var icon: String {
        switch self {
        case .overview: return "bolt.fill"
        case .health:   return "heart.fill"
        case .settings: return "gearshape.fill"
        case .about:    return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .overview: return .mint
        case .health:   return .pink
        case .settings: return .purple
        case .about:    return .blue
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: – Main App View (root)
// ─────────────────────────────────────────────────

struct MainAppView: View {
    @EnvironmentObject var manager: MonitorManager
    @State private var selectedTab: AppTab = .overview

    var body: some View {
        Group {
            if manager.showOnboarding {
                NotificationPermissionView()
                    .environmentObject(manager)
                    .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: manager.showOnboarding)
        .frame(minWidth: 850, idealWidth: 850, minHeight: 650, idealHeight: 650)
        .background(Color(hue: 0.65, saturation: 0.22, brightness: 0.08))
        .onAppear {
            manager.handleAppWindowOpened()
        }
    }

    private var mainContent: some View {
        HStack(spacing: 0) {
            // ── Sidebar ───────────────────────────────────────────
            SidebarView(selectedTab: $selectedTab)

            // ── Content divider ───────────────────────────────────
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1)

            // ── Content area ──────────────────────────────────────
            ZStack {
                switch selectedTab {
                case .overview:
                    AppOverviewTab()
                        .environmentObject(manager)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .health:
                    AppHealthTab()
                        .environmentObject(manager)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .settings:
                    SettingsView()
                        .environmentObject(manager)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .about:
                    AboutView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hue: 0.65, saturation: 0.20, brightness: 0.10))
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: – Sidebar
// ─────────────────────────────────────────────────

private struct SidebarView: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        VStack(spacing: 0) {
            // App branding
            VStack(spacing: 6) {
                Image(systemName: "battery.75percent.bolt")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.mint, Color(hue: 0.45, saturation: 0.7, brightness: 0.9)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Text("Battery")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1)
            }
            .padding(.top, 28)
            .padding(.bottom, 28)

            // Nav items
            VStack(spacing: 4) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    SidebarItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            // Version badge
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.2))
                .padding(.bottom, 16)
        }
        .frame(width: 80)
        .background(Color(hue: 0.65, saturation: 0.25, brightness: 0.07))
    }
}

private struct SidebarItem: View {
    let tab:        AppTab
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? tab.tint : .white.opacity(0.35))
                    .frame(width: 32, height: 32)
                    .background(isSelected ? tab.tint.opacity(0.18) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                Text(tab.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? tab.tint : .white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
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
// MARK: – Overview Tab
// ─────────────────────────────────────────────────

private struct AppOverviewTab: View {
    @EnvironmentObject var manager: MonitorManager

    var info: BatteryInfo { manager.batteryInfo }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Battery Overview")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(manager.lastUpdated.map { "Updated \($0.relativeTimeString)" } ?? "Loading…")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    // Monitor toggle
                    Button(action: {
                        if manager.isRunning { manager.stop() } else { manager.start() }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: manager.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text(manager.isRunning ? "Pause" : "Monitor")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(manager.isRunning ? .orange : .mint)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background((manager.isRunning ? Color.orange : Color.mint).opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke((manager.isRunning ? Color.orange : Color.mint).opacity(0.3), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .disableFocusEffect()
                    .focusable(false)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }

                    Button(action: { manager.refreshNow() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .disableFocusEffect()
                    .focusable(false)
                    .onHover { inside in
                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }

                // Main gauge + stats
                HStack(alignment: .top, spacing: 24) {
                    // Large gauge
                    AppGaugeView(info: info)
                        .frame(width: 220, height: 220)

                    // Right side stats
                    VStack(spacing: 14) {
                        AppStatCard(
                            icon: "powerplug.fill",
                            tint: .mint,
                            label: "Power Source",
                            value: info.powerSource.displayName
                        )
                        AppStatCard(
                            icon: "arrow.clockwise.circle.fill",
                            tint: .blue,
                            label: "Charge Cycles",
                            value: info.health.cycleCount > 0 ? "\(info.health.cycleCount)" : "—"
                        )
                        AppStatCard(
                            icon: "thermometer.medium",
                            tint: .orange,
                            label: "Temperature",
                            value: info.health.temperature > 0
                                ? String(format: "%.1f°C", info.health.temperature)
                                : "—"
                        )
                        AppStatCard(
                            icon: "bolt.fill",
                            tint: .yellow,
                            label: "Power Draw",
                            value: info.health.wattage > 0
                                ? String(format: "%.1f W", info.health.wattage)
                                : "—"
                        )
                    }
                }

                // Time remaining card
                AppTimeCard(info: info)

                // Health summary
                AppHealthSummaryCard(health: info.health)
            }
            .padding(28)
        }
    }
}

// ─────────────────────────────────────────────────

private struct AppGaugeView: View {
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
            // Outer glow
            Circle()
                .stroke(gaugeColor.opacity(0.08), lineWidth: 28)

            // Track ring
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 14)

            // Progress ring with glow
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [gaugeColor.opacity(0.5), gaugeColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle:   .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: gaugeColor.opacity(0.5), radius: 8)
                .animation(.spring(response: 1.2, dampingFraction: 0.7), value: animatedProgress)

            // Center content
            VStack(spacing: 4) {
                if info.isPluggedIn && info.chargeStatus.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.mint)
                }
                Text("\(info.percentage)%")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(info.chargeStatus.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: info.percentage) { _ in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
    }
}

private struct AppStatCard: View {
    let icon:  String
    let tint:  Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct AppTimeCard: View {
    let info: BatteryInfo

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: info.isPluggedIn ? "bolt.circle.fill" : "clock.fill")
                .font(.system(size: 24))
                .foregroundStyle(info.isPluggedIn ? .mint : .white.opacity(0.6))
            VStack(alignment: .leading, spacing: 3) {
                Text(info.isPluggedIn ? "Time to Full" : "Time Remaining")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                Text(info.timeRemainingString)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct AppHealthSummaryCard: View {
    let health: BatteryHealth
    @State private var animatedHealth: Double = 0

    var healthColor: Color {
        switch health.condition {
        case .normal:         return Color(hue: 0.36, saturation: 0.72, brightness: 0.85)
        case .replaceSoon:    return .yellow
        case .serviceBattery: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Battery Health", systemImage: "heart.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(health.percentage > 0
                     ? "\(Int(health.percentage))% · \(health.conditionLabel)"
                     : "Unavailable")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(healthColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [healthColor.opacity(0.7), healthColor],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * animatedHealth, height: 8)
                        .shadow(color: healthColor.opacity(0.4), radius: 4)
                        .animation(.spring(response: 1.2, dampingFraction: 0.7), value: animatedHealth)
                }
            }
            .frame(height: 8)

            if health.designCapacity > 0 {
                HStack(spacing: 24) {
                    CapacityLabel(label: "Design", value: "\(health.designCapacity) mAh")
                    CapacityLabel(label: "Current Max", value: "\(health.maxCapacity) mAh")
                    if health.voltage > 0 {
                        CapacityLabel(label: "Voltage", value: String(format: "%.2f V", health.voltage))
                    }
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear {
            withAnimation { animatedHealth = min(1, health.percentage / 100.0) }
        }
    }
}

private struct CapacityLabel: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.35))
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: – Health Tab
// ─────────────────────────────────────────────────

private struct AppHealthTab: View {
    @EnvironmentObject var manager: MonitorManager

    var info:   BatteryInfo   { manager.batteryInfo }
    var health: BatteryHealth { info.health }

    var healthColor: Color {
        switch health.condition {
        case .normal:         return Color(hue: 0.36, saturation: 0.72, brightness: 0.85)
        case .replaceSoon:    return .yellow
        case .serviceBattery: return .red
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Battery Health")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Condition banner
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(healthColor.opacity(0.15))
                            .frame(width: 60, height: 60)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(healthColor)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(health.conditionLabel)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(healthColor)
                        Text(health.percentage > 0
                             ? "\(Int(health.percentage))% of original capacity"
                             : "Health data unavailable")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                }
                .padding(18)
                .background(healthColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Detailed stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    HealthStatCell(icon: "arrow.clockwise", tint: .blue, label: "Charge Cycles",
                                   value: health.cycleCount > 0 ? "\(health.cycleCount)" : "—")
                    HealthStatCell(icon: "bolt.fill", tint: .yellow, label: "Design Capacity",
                                   value: health.designCapacity > 0 ? "\(health.designCapacity) mAh" : "—")
                    HealthStatCell(icon: "battery.100percent", tint: .mint, label: "Current Max",
                                   value: health.maxCapacity > 0 ? "\(health.maxCapacity) mAh" : "—")
                    HealthStatCell(icon: "thermometer.medium", tint: .orange, label: "Temperature",
                                   value: health.temperature > 0
                                       ? String(format: "%.1f°C", health.temperature) : "—")
                    HealthStatCell(icon: "bolt.circle.fill", tint: .purple, label: "Voltage",
                                   value: health.voltage > 0
                                       ? String(format: "%.3f V", health.voltage) : "—")
                    HealthStatCell(icon: "waveform.path.ecg", tint: .pink, label: "Current Draw",
                                   value: health.wattage > 0
                                       ? String(format: "%.2f W", health.wattage) : "—")
                }

                // Cycle count guidance
                VStack(alignment: .leading, spacing: 10) {
                    Text("CYCLE COUNT GUIDANCE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                        .tracking(1)

                    HStack(spacing: 0) {
                        CycleGuideBar(label: "New", range: "0–200", color: .mint, width: 0.3)
                        CycleGuideBar(label: "Good", range: "200–500", color: .yellow, width: 0.35)
                        CycleGuideBar(label: "Aging", range: "500–1000", color: .orange, width: 0.25)
                        CycleGuideBar(label: "Replace", range: "1000+", color: .red, width: 0.1)
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())

                    Text("Apple designs MacBook batteries to retain up to 80% capacity at 1000 cycles.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(18)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(28)
        }
    }
}

private struct HealthStatCell: View {
    let icon:  String
    let tint:  Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct CycleGuideBar: View {
    let label: String
    let range: String
    let color: Color
    let width: Double

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(color.opacity(0.6))
                .frame(width: geo.size.width * width)
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: – Preview
// ─────────────────────────────────────────────────

#Preview {
    MainAppView()
        .environmentObject(MonitorManager.shared)
}
