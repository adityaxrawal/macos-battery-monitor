// BatteryInfo.swift
// Native IOKit/IOPowerSources wrapper — reads all relevant battery properties.
// Uses AppleRawMaxCapacity for accurate health percentage.

import Foundation
import IOKit.ps
import IOKit

// ─────────────────────────────────────────────────
// MARK: – Data Models
// ─────────────────────────────────────────────────

enum PowerSource: String {
    case battery = "Battery Power"
    case ac      = "AC Power"
    case unknown = "Unknown"

    var isPluggedIn: Bool { self == .ac }

    var displayName: String {
        switch self {
        case .battery: return "Battery"
        case .ac:      return "Power Adapter"
        case .unknown: return "Unknown"
        }
    }
}

enum ChargeStatus: String {
    case charging        = "Charging"
    case discharging     = "Discharging"
    case charged         = "Charged"
    case finishingCharge = "Finishing Charge"
    case notCharging     = "Not Charging"   // AC attached, optimised charging
    case unknown         = "Unknown"

    var displayName: String {
        switch self {
        case .charging:        return "Charging"
        case .discharging:     return "Discharging"
        case .charged:         return "Fully Charged"
        case .finishingCharge: return "Finishing Charge"
        case .notCharging:     return "Plugged In"
        case .unknown:         return "Unknown"
        }
    }

    var isCharging: Bool {
        self == .charging || self == .finishingCharge
    }
}

enum HealthCondition {
    case normal, replaceSoon, serviceBattery
}

struct BatteryHealth {
    let cycleCount:       Int    // actual charge cycles used
    let designCapacity:   Int    // mAh design capacity
    let maxCapacity:      Int    // mAh raw current max (AppleRawMaxCapacity)
    var percentage:       Double // matched with system preferences
    let temperature:      Double // degrees Celsius
    let voltage:          Double // Volts
    let amperage:         Double // Amps (negative = discharging)
    let wattage:          Double // Watts

    var condition: HealthCondition {
        switch percentage {
        case 80...:   return .normal
        case 60..<80: return .replaceSoon
        default:      return .serviceBattery
        }
    }

    var conditionLabel: String {
        switch condition {
        case .normal:         return "Normal"
        case .replaceSoon:    return "Replace Soon"
        case .serviceBattery: return "Service Battery"
        }
    }

    static let unavailable = BatteryHealth(
        cycleCount: 0, designCapacity: 0, maxCapacity: 0, percentage: 0,
        temperature: 0, voltage: 0, amperage: 0, wattage: 0
    )
}

struct BatteryInfo {
    // ── Core state ────────────────────────────────
    let percentage:    Int           // 0–100
    let powerSource:   PowerSource
    let chargeStatus:  ChargeStatus
    let isPresent:     Bool          // false on Mac mini / Mac Pro

    // ── Time estimates ────────────────────────────
    let timeToEmpty:   Int?          // minutes remaining if on battery (nil = unknown)
    let timeToFull:    Int?          // minutes until fully charged (nil = not charging)

    // ── Health ────────────────────────────────────
    var health:        BatteryHealth

    // ── Computed helpers ──────────────────────────
    var isPluggedIn:   Bool { powerSource.isPluggedIn }
    var isCharging:    Bool { chargeStatus.isCharging }
    var isLow:         Bool { percentage <= 30 && !isPluggedIn }
    var isCritical:    Bool { percentage <= 10 && !isPluggedIn }

    var timeRemainingString: String {
        if isPluggedIn {
            if chargeStatus == .charged { return "Fully Charged" }
            if let mins = timeToFull, mins > 0 {
                let h = mins / 60, m = mins % 60
                return h > 0 ? "\(h)h \(m)m until full" : "\(m)m until full"
            }
            return chargeStatus.displayName
        } else {
            if let mins = timeToEmpty, mins > 0 {
                let h = mins / 60, m = mins % 60
                return h > 0 ? "\(h)h \(m)m remaining" : "\(m)m remaining"
            }
            return "Calculating…"
        }
    }

    /// A placeholder value used before the first real read
    static let placeholder = BatteryInfo(
        percentage:   0,
        powerSource:  .unknown,
        chargeStatus: .unknown,
        isPresent:    true,
        timeToEmpty:  nil,
        timeToFull:   nil,
        health:       .unavailable
    )
}

// ─────────────────────────────────────────────────
// MARK: – IOKit Reader
// ─────────────────────────────────────────────────

enum BatteryReader {

    /// Perform a synchronous read from IOPowerSources + IORegistry.
    /// Always returns a valid `BatteryInfo` — never throws.
    static func read() -> BatteryInfo {
        // ── 1. Power source snapshot ──────────────────────────────
        let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]

        guard let psRef  = list.first,
              let psDict = IOPSGetPowerSourceDescription(blob, psRef)
                            .takeUnretainedValue() as? [String: AnyObject]
        else {
            // No battery found (Mac mini, Mac Pro, etc.)
            return BatteryInfo(percentage: 100, powerSource: .ac,
                               chargeStatus: .unknown, isPresent: false,
                               timeToEmpty: nil, timeToFull: nil,
                               health: .unavailable)
        }

        // ── 2. Parse percentage ───────────────────────────────────
        let currentCapacity = psDict[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCapacityPS   = psDict[kIOPSMaxCapacityKey]     as? Int ?? 100
        let percentage      = maxCapacityPS > 0
            ? Int(Double(currentCapacity) / Double(maxCapacityPS) * 100.0)
            : currentCapacity

        // ── 3. Power source ───────────────────────────────────────
        let sourceRaw   = psDict[kIOPSPowerSourceStateKey] as? String ?? ""
        let powerSource = sourceRaw == kIOPSACPowerValue
            ? PowerSource.ac : PowerSource.battery

        // ── 4. Charge status ──────────────────────────────────────
        let isCharging   = psDict[kIOPSIsChargingKey] as? Bool ?? false
        let isCharged    = psDict[kIOPSIsChargedKey]  as? Bool ?? false
        let chargeStatus: ChargeStatus = {
            let raw = psDict["Battery Status"] as? String
            if let r = raw {
                if r.contains("AC Attached; Not Charging") { return .notCharging }
                if r.contains("Finishing")                 { return .finishingCharge }
            }
            if isCharged                           { return .charged }
            if isCharging                          { return .charging }
            if powerSource == .battery             { return .discharging }
            return .notCharging
        }()

        // ── 5. Time remaining ─────────────────────────────────────
        var timeToEmpty: Int?
        var timeToFull:  Int?

        if powerSource == .battery {
            let mins = psDict[kIOPSTimeToEmptyKey] as? Int ?? -1
            if mins > 0 { timeToEmpty = mins }
        } else {
            let mins = psDict[kIOPSTimeToFullChargeKey] as? Int ?? -1
            if mins > 0 { timeToFull = mins }
        }

        // ── 6. Health + extra data via IORegistry ─────────────────
        let health = readHealthFromIORegistry()

        return BatteryInfo(
            percentage:   min(100, max(0, percentage)),
            powerSource:  powerSource,
            chargeStatus: chargeStatus,
            isPresent:    true,
            timeToEmpty:  timeToEmpty,
            timeToFull:   timeToFull,
            health:       health
        )
    }

    // ── IORegistry health + sensor reader ────────────────────────
    private static func readHealthFromIORegistry() -> BatteryHealth {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != IO_OBJECT_NULL else { return .unavailable }
        defer { IOObjectRelease(service) }

        func intProp(_ key: String) -> Int? {
            guard let v = IORegistryEntryCreateCFProperty(
                service, key as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() else { return nil }
            return (v as? NSNumber)?.intValue
        }

        let cycles  = intProp("CycleCount")             ?? 0
        let design  = intProp("DesignCapacity")         ?? 0

        // AppleRawMaxCapacity is the actual current max in mAh (not normalized)
        // Fall back to MaxCapacity if unavailable
        let rawMax  = intProp("AppleRawMaxCapacity")
                   ?? intProp("NominalChargeCapacity")
                   ?? intProp("MaxCapacity")
                   ?? 0

        // Health % = raw current max / design capacity
        let percent: Double = (design > 0 && rawMax > 0)
            ? min(100, Double(rawMax) / Double(design) * 100.0)
            : 0

        // Temperature: stored as centidegrees Celsius in IORegistry
        let tempRaw  = intProp("Temperature") ?? 0
        let tempC    = Double(tempRaw) / 100.0

        // Voltage in mV → V
        let voltMV   = intProp("Voltage") ?? 0
        let voltage  = Double(voltMV) / 1000.0

        // Amperage in mA → A (negative when discharging)
        let ampMA    = intProp("Amperage") ?? 0
        let amperage = Double(ampMA) / 1000.0

        // Wattage = V × A
        let wattage  = voltage * abs(amperage)

        return BatteryHealth(
            cycleCount:     cycles,
            designCapacity: design,
            maxCapacity:    rawMax,
            percentage:     percent,
            temperature:    tempC,
            voltage:        voltage,
            amperage:       amperage,
            wattage:        wattage
        )
    }
}
