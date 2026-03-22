// AboutView.swift
// Premium about screen — shown from popover action strip or app sidebar.

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var isPopover: Bool = false
    var onBack: (() -> Void)? = nil

    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                          as? String ?? "1.2.0"

    var body: some View {
        ZStack {
            // Background
            Color(hue: 0.65, saturation: 0.20, brightness: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if isPopover {
                    // ── Popover header: Back + title ──────────────────
                    HStack {
                        if let onBack = onBack {
                            Button(action: onBack) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Back")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .disableFocusEffect()
                            .focusable(false)
                            .onHover { inside in
                                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    popoverAboutContent

                } else {
                    // ── Full-window header: consistent with Overview/Health ──
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("About")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Battery Monitor \(version)")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                        // Version pill
                        Text("v\(version)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.blue.opacity(0.9))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 0.5))
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                    fullAboutContent
                }
            }
        }
        .frame(minWidth: isPopover ? 300 : 340, maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: isPopover ? true : false)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // ── Popover version: centered identity + features ──────────────────────
    private var popoverAboutContent: some View {
        VStack(spacing: 0) {
            // App identity (centered, compact)
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.mint.opacity(0.2), .mint.opacity(0.03)],
                                center: .center, startRadius: 0, endRadius: 42
                            )
                        )
                        .frame(width: 80, height: 80)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.mint, Color(hue: 0.45, saturation: 0.7, brightness: 0.9)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }

                Text("Battery Monitor")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Version \(version)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
                .padding(.horizontal, 24)

            // Feature list
            VStack(alignment: .leading, spacing: 10) {
                AboutRow(icon: "bell.badge.fill",  tint: .orange,
                         text: "Smart alerts at critical, low, and high charge levels.")
                AboutRow(icon: "bolt.heart.fill",  tint: .mint,
                         text: "Protect battery health — reminded to unplug above ≥85%.")
                AboutRow(icon: "cpu.fill",         tint: .blue,
                         text: "Native IOKit reads — no background processes or scripts.")
                AboutRow(icon: "heart.fill",       tint: .pink,
                         text: "Accurate health via AppleRawMaxCapacity IORegistry key.")
                AboutRow(icon: "gearshape.2.fill", tint: .purple,
                         text: "Fully configurable thresholds, intervals & notification toggles.")
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)

            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
                .padding(.horizontal, 24)

            VStack(spacing: 3) {
                Text("Built for macOS 13 Ventura and later")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
                Text("No third-party dependencies · MIT Licence")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.vertical, 14)
        }
    }

    // ── Full-window version: scrollable with cards ─────────────────────────
    private var fullAboutContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // App identity card
                HStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.mint.opacity(0.20), .mint.opacity(0.03)],
                                    center: .center, startRadius: 0, endRadius: 46
                                )
                            )
                            .frame(width: 88, height: 88)
                        Image(systemName: "battery.75percent.bolt")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.mint, Color(hue: 0.45, saturation: 0.7, brightness: 0.9)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Battery Monitor")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("A minimal, native macOS battery monitoring app with smart alerts and health insights.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Features section
                VStack(alignment: .leading, spacing: 10) {
                    Text("FEATURES")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                        .tracking(1.2)

                    VStack(alignment: .leading, spacing: 0) {
                        FullAboutRow(icon: "bell.badge.fill",  tint: .orange,
                                     title: "Smart Alerts",
                                     text: "Critical, low, and high charge level notifications.")
                        featureDivider
                        FullAboutRow(icon: "bolt.heart.fill",  tint: .mint,
                                     title: "Health Protection",
                                     text: "Reminded to unplug when battery exceeds ≥85%.")
                        featureDivider
                        FullAboutRow(icon: "cpu.fill",         tint: .blue,
                                     title: "Native IOKit",
                                     text: "Pure Swift reads — zero background processes or scripts.")
                        featureDivider
                        FullAboutRow(icon: "heart.fill",       tint: .pink,
                                     title: "Accurate Health",
                                     text: "Uses AppleRawMaxCapacity IORegistry key for precision.")
                        featureDivider
                        FullAboutRow(icon: "gearshape.2.fill", tint: .purple,
                                     title: "Fully Configurable",
                                     text: "Thresholds, intervals, and per-alert notification toggles.")
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Tech details cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    TechCard(icon: "apple.logo", tint: .white.opacity(0.7), label: "Platform", value: "macOS 13+")
                    TechCard(icon: "swift",      tint: Color(hue: 0.05, saturation: 0.85, brightness: 0.95), label: "Language", value: "Swift / SwiftUI")
                    TechCard(icon: "lock.shield.fill", tint: .mint, label: "Dependencies", value: "None")
                    TechCard(icon: "doc.fill",   tint: .blue, label: "Licence", value: "MIT")
                }
            }
            .padding(28)
        }
    }

    private var featureDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
    }
}

// ─────────────────────────────────────────────────
// MARK: – Sub-components
// ─────────────────────────────────────────────────

private struct AboutRow: View {
    let icon:  String
    let tint:  Color
    let text:  String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(tint.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .padding(.top, 1)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

private struct FullAboutRow: View {
    let icon:  String
    let tint:  Color
    let title: String
    let text:  String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(tint.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.42))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

private struct TechCard: View {
    let icon:  String
    let tint:  Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.35))
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    AboutView()
}
