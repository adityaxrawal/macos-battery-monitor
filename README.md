# 🔋 Battery Monitor v1.1.0 — Native macOS Menu Bar App

A polished, production-grade macOS **menu-bar application** that monitors your battery health using native IOKit APIs — no third-party dependencies, no background scripts.

---

## What's New in v1.1.0

| Area | v1.0.0 | v1.1.0 |
|---|---|---|
| **UI surface** | Standalone window | **Menu-bar icon + popover** (no Dock icon) |
| **Battery data** | Bash subprocess (`pmset`) | **Native IOKit reads** — instant, always accurate |
| **Live data** | None displayed | Live %, charge status, time remaining, health |
| **Thresholds** | Hardcoded in shell script | **User-configurable sliders** in Settings |
| **Check interval** | Fixed 5 min | Configurable: 1 / 2 / 5 / 10 / 15 min |
| **Notifications** | Bash + `osascript` | Native `UNUserNotificationCenter` |
| **Per-notification toggle** | ✗ | ✓ Enable/disable each alert independently |
| **Battery health display** | ✗ | ✓ Health %, cycle count, condition label |
| **Version** | 1.0.0 | **1.1.0** |

---

## Features

- **🔋 Animated battery gauge** — ring-style with color-coded fill (green / amber / red)
- **⚡ Smart alerts**:
  - 🚨 Critical (≤ 10% — configurable) — *Basso* sound
  - 🔋 Low (≤ 30% — configurable) — *Sosumi* sound
  - ⚡ Unplug reminder (≥ 85% — configurable) — *Glass* sound
  - ⚠️ Draining on AC (charger fault or underpowered adapter) — *Funk* sound
- **📊 Live data**: percentage, charge status, time remaining, power source
- **❤️ Battery health**: max capacity vs design capacity, cycle count, condition label
- **⚙️ Settings panel**: sliders for all thresholds, interval picker, per-notification toggles
- **🚀 Launch at Login** via `SMAppService` (macOS 13+)
- **No Dock icon** — runs quietly in the menu bar

---

## Project Layout

```
.
├── Sources/
│   ├── BatteryMonitorApp.swift      ← App entry, MenuBarExtra + AppDelegate
│   ├── BatteryInfo.swift            ← IOKit/IOPowerSources native battery reader
│   ├── MonitorManager.swift         ← Timer, alerts (UNNotifications), settings
│   ├── MenuBarPopoverView.swift     ← Primary UI — animated gauge + action strip
│   ├── SettingsView.swift           ← Thresholds, intervals, notification toggles
│   └── AboutView.swift              ← Version info + feature summary
├── Resources/
│   └── AppIcon.icns
├── Info.plist
├── BatteryMonitor.entitlements
├── project.yml                      ← xcodegen config (LSUIElement, v1.1.0)
└── Makefile                         ← End-to-end build commands (make dmg, make icons)
```

---

## Build Instructions

### 1. Install prerequisites (once)

```bash
# Xcode Command Line Tools
xcode-select --install

# xcodegen — generates the .xcodeproj from project.yml
brew install xcodegen

# (Optional) xcpretty — prettier build output
gem install xcpretty
```

### 2. Build and package

```bash
make dmg
```

This produces **`BatteryMonitor-1.2.0.dmg`** in the same directory.

### 3. Install

1. Double-click the DMG
2. Drag **Battery Monitor.app** → **Applications**
3. Launch it — a battery icon appears in your **menu bar**
4. Click the icon to open the live popover
5. Open **Settings ⚙** → enable **Launch at Login** for auto-start

---

## How It Works

- **No background processes.** The app reads battery state via `IOPowerSources` (IOKit) — the same API macOS itself uses. This is synchronous and instant.
- **Repeating timer** fires every N minutes (configurable: 1/2/5/10/15). Each tick reads battery state and evaluates alert conditions.
- **Alert de-duplication** — each alert (Critical, Low, High, Drain-on-AC) fires only once per condition entry. It resets automatically when the condition clears.
- **UNUserNotificationCenter** delivers persistent alerts (not banners) so they don't auto-dismiss.
- **SMAppService** handles Launch at Login (macOS 13+). Reflected in System Settings → General → Login Items.
- **UserDefaults** persists all settings (thresholds, interval, notification toggles, last-running state).

---

## Customising Thresholds

Via the Settings panel (click the ⚙ gear in the popover) — no rebuilding required.

Or you can edit the defaults in `Sources/MonitorManager.swift`:

```swift
Defaults.criticalThreshold: 10,   // %
Defaults.lowThreshold:      30,   // %
Defaults.highThreshold:     85,   // %
Defaults.checkInterval:      5,   // minutes
```

---

## Uninstall

1. Quit Battery Monitor (Quit button in the popover)
2. Move it from Applications to Trash
3. The Login Item is removed automatically when the app is deleted
4. Optional cleanup: `~/Library/Preferences/com.user.BatteryMonitor.plist`

---

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ (build only — not needed at runtime)

---

## Changelog

### v1.1.0
- Converted to menu-bar-only app (no Dock icon)
- Replaced bash engine with native IOKit battery reads
- Added live battery data in popover (%, time remaining, health)
- Added configurable thresholds and check intervals via Settings
- Added per-notification toggles
- Switched to UNUserNotificationCenter (persistent alert-style notifications)
- Animated battery ring gauge with color-coded fill

### v1.0.0
- Initial release — SwiftUI window app wrapping battery_monitor.sh
