// BatteryMonitorApp.swift
// Dual-mode app: shows in Dock (for full app window) AND menu bar (for popover).
// First launch triggers onboarding inside the app window.

import SwiftUI
import AppKit

@main
struct BatteryMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var manager = MonitorManager.shared

    var body: some Scene {
        // ── Full app window (opened from Dock / Finder) ────────────
        WindowGroup(id: "main") {
            MainAppView()
                .environmentObject(manager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Remove default menu items that don't apply
            CommandGroup(replacing: .newItem) {}
        }

        // ── Menu bar extra (always visible in status bar) ──────────
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(manager)
        } label: {
            MenuBarLabel(info: manager.batteryInfo, isRunning: manager.isRunning)
        }
        .menuBarExtraStyle(.window)   // renders as floating popover

        // Settings window — opened from the popover's gear button
        Settings {
            SettingsView()
                .environmentObject(manager)
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: – Menu Bar Label (minimal icon)
// ─────────────────────────────────────────────────

/// Renders a minimal status-bar icon. Small and clean — icon only, no text by default.
private struct MenuBarLabel: View {
    let info:      BatteryInfo
    let isRunning: Bool

    var batteryIcon: String {
        return "bolt.fill"
    }

    var iconColor: Color {
        if !isRunning      { return .secondary }
        if info.isCritical { return .red }
        if info.isLow      { return .orange }
        if info.isPluggedIn && info.chargeStatus.isCharging { return .mint }
        return .primary
    }

    var body: some View {
        // Minimal: just the icon, small and clean
        Image(systemName: batteryIcon)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(iconColor)
            .font(.system(size: 13, weight: .medium))
    }
}

// ─────────────────────────────────────────────────
// MARK: – AppDelegate
// ─────────────────────────────────────────────────

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Auto-resume monitoring if it was active when the app last quit
        if MonitorManager.shared.shouldAutoResume {
            MonitorManager.shared.start()
        }

        // Re-check notification permission status on each launch
        MonitorManager.shared.checkNotificationAuthStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        MonitorManager.shared.stop()
    }

    // Keep app alive when all windows are closed (still lives in menu bar)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
