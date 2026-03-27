// MonitorManager.swift
// Central controller — reads battery via IOKit, fires native UNNotifications,
// manages the repeating-timer lifecycle, and persists all user settings.

import Foundation
import ServiceManagement
import UserNotifications
import AppKit
import Combine

// ─────────────────────────────────────────────────
// MARK: – Settings Keys
// ─────────────────────────────────────────────────

private enum Defaults {
    static let wasRunning        = "wasRunning"
    static let checkInterval     = "checkIntervalMinutes"   // Int (1/2/5/10/15)
    static let criticalThreshold = "criticalThreshold"      // Int (%)
    static let lowThreshold      = "lowThreshold"           // Int (%)
    static let highThreshold     = "highThreshold"          // Int (%)
    static let notifyCritical    = "notifyCritical"         // Bool
    static let notifyLow         = "notifyLow"
    static let notifyHigh        = "notifyHigh"
    static let notifyDrainOnAC   = "notifyDrainOnAC"
    static let hasLaunchedBefore = "hasLaunchedBefore"      // Bool — for onboarding
    static let notifPermAsked    = "notificationPermissionAsked" // Bool
}

// ─────────────────────────────────────────────────
// MARK: – MonitorManager
// ─────────────────────────────────────────────────

@MainActor
final class MonitorManager: ObservableObject {

    static let shared = MonitorManager()

    // ── Published state ──────────────────────────────────────────
    @Published private(set) var batteryInfo: BatteryInfo = .placeholder
    @Published private(set) var isRunning:   Bool        = false
    @Published private(set) var launchAtLogin: Bool      = false
    @Published private(set) var lastUpdated: Date?

    /// Whether the in-app onboarding/permission screen should be shown
    @Published private(set) var showOnboarding: Bool = false

    /// Current notification authorization status
    @Published private(set) var notificationAuthStatus: UNAuthorizationStatus = .notDetermined

    // ── User-configurable settings (auto-save to UserDefaults) ───
    @Published var checkIntervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(checkIntervalMinutes, forKey: Defaults.checkInterval)
            restartTimerIfRunning()
        }
    }
    @Published var criticalThreshold: Int {
        didSet { UserDefaults.standard.set(criticalThreshold, forKey: Defaults.criticalThreshold) }
    }
    @Published var lowThreshold: Int {
        didSet { UserDefaults.standard.set(lowThreshold,      forKey: Defaults.lowThreshold) }
    }
    @Published var highThreshold: Int {
        didSet { UserDefaults.standard.set(highThreshold,     forKey: Defaults.highThreshold) }
    }
    @Published var notifyCritical:  Bool {
        didSet { UserDefaults.standard.set(notifyCritical,  forKey: Defaults.notifyCritical) }
    }
    @Published var notifyLow:       Bool {
        didSet { UserDefaults.standard.set(notifyLow,       forKey: Defaults.notifyLow) }
    }
    @Published var notifyHigh:      Bool {
        didSet { UserDefaults.standard.set(notifyHigh,      forKey: Defaults.notifyHigh) }
    }
    @Published var notifyDrainOnAC: Bool {
        didSet { UserDefaults.standard.set(notifyDrainOnAC, forKey: Defaults.notifyDrainOnAC) }
    }

    // ── Auto-resume ──────────────────────────────────────────────
    var shouldAutoResume: Bool {
        UserDefaults.standard.bool(forKey: Defaults.wasRunning)
    }

    var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: Defaults.hasLaunchedBefore)
    }

    // ── Private state ────────────────────────────────────────────
    private var timer: Timer?

    // Alert de-duplication — prevents repeat notifications for the same condition
    private var alertedCritical  = false
    private var alertedLow       = false
    private var alertedHigh      = false
    private var alertedDrainOnAC = false

    /// Cached exact Apple-calibrated battery health percentage (from system_profiler)
    private var accurateHealthPercentage: Double?
    private var healthSyncTask: Task<Void, Never>?

    // ─────────────────────────────────────────────
    private init() {
        let ud = UserDefaults.standard

        // Set defaults if not previously configured
        let defaults: [String: Any] = [
            Defaults.checkInterval:     5,
            Defaults.criticalThreshold: 10,
            Defaults.lowThreshold:      30,
            Defaults.highThreshold:     85,
            Defaults.notifyCritical:    true,
            Defaults.notifyLow:         true,
            Defaults.notifyHigh:        true,
            Defaults.notifyDrainOnAC:   true,
            Defaults.wasRunning:        true
        ]
        ud.register(defaults: defaults)

        checkIntervalMinutes = ud.integer(forKey: Defaults.checkInterval)
        criticalThreshold    = ud.integer(forKey: Defaults.criticalThreshold)
        lowThreshold         = ud.integer(forKey: Defaults.lowThreshold)
        highThreshold        = ud.integer(forKey: Defaults.highThreshold)
        notifyCritical       = ud.bool(forKey: Defaults.notifyCritical)
        notifyLow            = ud.bool(forKey: Defaults.notifyLow)
        notifyHigh           = ud.bool(forKey: Defaults.notifyHigh)
        notifyDrainOnAC      = ud.bool(forKey: Defaults.notifyDrainOnAC)

        refreshLaunchAtLoginStatus()

        // Populate immediately so the UI never shows "placeholder" on launch
        refreshBattery()

        // Check existing notification permission status (don't ask yet)
        checkNotificationAuthStatus()

        // Start background health polling
        startHealthSyncTask()
    }

    // ─────────────────────────────────────────────
    // MARK: – Start / Stop / Refresh
    // ─────────────────────────────────────────────

    func start() {
        guard !isRunning else { return }
        refreshBattery()
        scheduleTimer()
        isRunning = true
        UserDefaults.standard.set(true, forKey: Defaults.wasRunning)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        healthSyncTask?.cancel()
        isRunning = false
        UserDefaults.standard.set(false, forKey: Defaults.wasRunning)
    }

    /// One-shot refresh — called from UI without starting the monitor
    func refreshNow() {
        refreshBattery()
    }

    // ─────────────────────────────────────────────
    // MARK: – First Launch / Onboarding
    // ─────────────────────────────────────────────

    /// Call this when the app window is opened from the Dock/Finder
    func handleAppWindowOpened() {
        if isFirstLaunch {
            showOnboarding = true
        }
    }

    func markLaunchedBefore() {
        UserDefaults.standard.set(true, forKey: Defaults.hasLaunchedBefore)
    }

    func dismissOnboarding() {
        showOnboarding = false
        markLaunchedBefore()
    }

    // ─────────────────────────────────────────────
    // MARK: – Internal
    // ─────────────────────────────────────────────

    private func scheduleTimer() {
        let interval = TimeInterval(max(1, checkIntervalMinutes) * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshBattery()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func restartTimerIfRunning() {
        guard isRunning else { return }
        timer?.invalidate()
        scheduleTimer()
    }

    private func refreshBattery() {
        var info = BatteryReader.read()
        if let accurate = accurateHealthPercentage {
            info.health.percentage = accurate
        }
        self.batteryInfo  = info
        self.lastUpdated  = Date()
        evaluateAlerts(for: info)
    }

    // ─────────────────────────────────────────────
    // MARK: – Settings Reset
    // ─────────────────────────────────────────────

    func resetToDefaults() {
        checkIntervalMinutes = 5
        criticalThreshold    = 10
        lowThreshold         = 30
        highThreshold        = 85
        notifyCritical       = true
        notifyLow            = true
        notifyHigh           = true
        notifyDrainOnAC      = true
    }

    // ─────────────────────────────────────────────
    // MARK: – Alert Logic
    // ─────────────────────────────────────────────

    private func evaluateAlerts(for info: BatteryInfo) {
        guard info.isPresent else { return }
        // Only send if authorized
        guard notificationAuthStatus == .authorized else { return }

        let pct = info.percentage
        let src = info.powerSource
        let chg = info.chargeStatus

        // ── Alert 1: Critical ──────────────────────────────────
        if notifyCritical && pct <= criticalThreshold && src == .battery {
            if !alertedCritical {
                sendNotification(
                    id:      "critical",
                    title:   "🚨 Critical Battery",
                    body:    "Battery at \(pct)%! Plug in immediately or your Mac will sleep.",
                    sound:   UNNotificationSound(named: UNNotificationSoundName("Basso"))
                )
                alertedCritical = true
            }
        } else {
            alertedCritical = false
        }

        // ── Alert 2: Low ───────────────────────────────────────
        if notifyLow && pct <= lowThreshold && pct > criticalThreshold && src == .battery {
            if !alertedLow {
                sendNotification(
                    id:    "low",
                    title: "🔋 Low Battery",
                    body:  "Battery at \(pct)% — plug in your charger soon.",
                    sound: UNNotificationSound(named: UNNotificationSoundName("Sosumi"))
                )
                alertedLow = true
            }
        } else {
            alertedLow = false
        }

        // ── Alert 3: High / Overcharge ─────────────────────────
        let isActivelyCharging = src == .ac && chg != .notCharging
        if notifyHigh && isActivelyCharging && pct >= highThreshold {
            if !alertedHigh {
                let body = (chg == .charged || pct == 100)
                    ? "Battery is at 100% and still plugged in — unplug to protect battery health."
                    : "Battery at \(pct)% and charging — unplug to protect battery health."
                sendNotification(
                    id:    "high",
                    title: "⚡ \(chg == .charged ? "Battery Full" : "Unplug Charger")",
                    body:  body,
                    sound: UNNotificationSound(named: UNNotificationSoundName("Glass"))
                )
                alertedHigh = true
            }
        } else {
            alertedHigh = false
        }

        // ── Alert 4: Draining on AC ────────────────────────────
        if notifyDrainOnAC && src == .ac && chg == .discharging {
            if !alertedDrainOnAC {
                sendNotification(
                    id:    "drainOnAC",
                    title: "⚠️ Charger Warning",
                    body:  "Battery is draining even while plugged in — check your charger or cable.",
                    sound: UNNotificationSound(named: UNNotificationSoundName("Funk"))
                )
                alertedDrainOnAC = true
            }
        } else {
            alertedDrainOnAC = false
        }
    }

    // ─────────────────────────────────────────────
    // MARK: – Notifications
    // ─────────────────────────────────────────────

    func checkNotificationAuthStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.notificationAuthStatus = settings.authorizationStatus
            }
        }
    }

    /// Called from the in-app onboarding / Settings permission card
    func requestNotificationPermission() async -> Bool {
        let granted = try? await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        )
        self.checkNotificationAuthStatus()
        UserDefaults.standard.set(true, forKey: Defaults.notifPermAsked)
        return granted ?? false
    }

    private func sendNotification(id: String, title: String, body: String,
                                  sound: UNNotificationSound? = .default) {
        // Register the category with a Dismiss action so macOS is more likely to show it as an Alert (permanent)
        let dismissAction = UNNotificationAction(identifier: "dismiss", title: "Dismiss", options: [])
        let category = UNNotificationCategory(identifier: "batteryAlert", actions: [dismissAction], intentIdentifiers: [], options: [.customDismissAction])
        UNUserNotificationCenter.current().setNotificationCategories([category])

        let content        = UNMutableNotificationContent()
        content.title      = title
        content.body       = body
        content.sound      = sound
        content.categoryIdentifier = "batteryAlert"
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        // Replace any previous notification with the same id
        let request = UNNotificationRequest(identifier: id,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request) { err in
            if let err { NSLog("BatteryMonitor: notification error — %@", err.localizedDescription) }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: – Launch at Login  (macOS 13+)
    // ─────────────────────────────────────────────

    func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                launchAtLogin = enabled
            } catch {
                NSLog("BatteryMonitor: launch-at-login error — %@",
                      error.localizedDescription)
            }
        }
    }

    private func refreshLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // ─────────────────────────────────────────────
    // MARK: – Accurate Health Sync
    // ─────────────────────────────────────────────

    private func startHealthSyncTask() {
        healthSyncTask = Task.detached(priority: .background) { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let pct = await self.fetchAccurateHealth() {
                    await MainActor.run {
                        self.accurateHealthPercentage = pct
                        self.refreshNow()
                    }
                }
                do {
                    // Sleep for 2 hours before checking again
                    try await Task.sleep(nanoseconds: 2 * 60 * 60 * 1_000_000_000)
                } catch {
                    return // Task cancelled, exit cleanly
                }
            }
        }
    }

    private func fetchAccurateHealth() async -> Double? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
                task.arguments = ["SPPowerDataType"]
                let pipe = Pipe()
                task.standardOutput = pipe
                try? task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                if let line = output.split(separator: "\n").first(where: { $0.contains("Maximum Capacity:") }) {
                    let digits = line.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                    if let val = Double(digits) {
                        continuation.resume(returning: val)
                        return
                    }
                }
                continuation.resume(returning: nil)
            }
        }
    }
}
