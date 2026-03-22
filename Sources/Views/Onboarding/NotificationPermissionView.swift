// NotificationPermissionView.swift
// Beautiful in-app onboarding shown on first launch — replaces OS-level dialog.

import SwiftUI
import UserNotifications

struct NotificationPermissionView: View {
    @EnvironmentObject var manager: MonitorManager
    @State private var isRequesting = false
    @State private var permissionGranted = false
    @State private var animate = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hue: 0.62, saturation: 0.25, brightness: 0.12),
                    Color(hue: 0.65, saturation: 0.30, brightness: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Icon ─────────────────────────────────────────
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.mint.opacity(0.25),
                                    Color.mint.opacity(0.05)
                                ],
                                center: .center, startRadius: 10, endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(animate ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                   value: animate)

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.mint, Color(hue: 0.45, saturation: 0.7, brightness: 0.9)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.bottom, 32)

                // ── Title ─────────────────────────────────────────
                VStack(spacing: 10) {
                    Text("Stay Informed")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Battery Monitor sends smart alerts\nwhen your battery needs attention.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.bottom, 36)

                // ── Feature rows ──────────────────────────────────
                VStack(spacing: 16) {
                    PermissionFeatureRow(
                        icon: "exclamationmark.triangle.fill",
                        tint: .red,
                        title: "Critical alerts",
                        subtitle: "When battery drops below your threshold"
                    )
                    PermissionFeatureRow(
                        icon: "battery.25percent",
                        tint: .orange,
                        title: "Low battery reminders",
                        subtitle: "Gentle nudge before you run out"
                    )
                    PermissionFeatureRow(
                        icon: "bolt.fill",
                        tint: .mint,
                        title: "Unplug reminders",
                        subtitle: "Protect long-term battery health"
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 44)

                // ── Actions ───────────────────────────────────────
                VStack(spacing: 12) {
                    Button(action: allowNotifications) {
                        HStack(spacing: 8) {
                            if isRequesting {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else if permissionGranted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 15, weight: .semibold))
                            } else {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Text(permissionGranted ? "Notifications Enabled!" : "Allow Notifications")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            if permissionGranted {
                                Color.green
                            } else {
                                LinearGradient(
                                    colors: [.mint, Color(hue: 0.45, saturation: 0.7, brightness: 0.9)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disableFocusEffect()
                    .focusable(false)
                    .disabled(isRequesting || permissionGranted)

                    Button(action: skip) {
                        Text("Not Now")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .disableFocusEffect()
                    .focusable(false)
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding(.vertical, 20)
        }
        .onAppear { animate = true }
    }

    private func allowNotifications() {
        isRequesting = true
        Task {
            let granted = await manager.requestNotificationPermission()
            isRequesting = false
            permissionGranted = granted
            if granted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    manager.dismissOnboarding()
                }
            }
        }
    }

    private func skip() {
        manager.dismissOnboarding()
    }
}

// ─────────────────────────────────────────────────
// MARK: – Feature Row
// ─────────────────────────────────────────────────

private struct PermissionFeatureRow: View {
    let icon:     String
    let tint:     Color
    let title:    String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()
        }
    }
}

#Preview {
    NotificationPermissionView()
        .environmentObject(MonitorManager.shared)
        .frame(width: 460, height: 620)
}
