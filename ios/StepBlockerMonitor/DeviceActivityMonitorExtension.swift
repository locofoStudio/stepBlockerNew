//
//  DeviceActivityMonitorExtension.swift
//  StepBlockerMonitor
//
//  Created by Arnaud Dirckx on 15/12/2025.
//

import Foundation
import DeviceActivity
import ManagedSettings
import FamilyControls

// This extension monitors blocked app usage in REAL-TIME.
// When the user has used blocked apps for the threshold duration, it blocks them.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    
    let store = ManagedSettingsStore()
    let sharedDefaults = UserDefaults(suiteName: "group.com.stepblocker.shared")
    let screenTimeDefaults = UserDefaults(suiteName: "group.com.locofoStudio.stepblocker")

    private enum Keys {
        // Written by extensions so the container app (RN) can pick them up.
        static let lastBlockedUsageStartedAt = "lastBlockedUsageStartedAt" // TimeInterval since 1970
        static let lastBlockedUsageBlockedAt = "lastBlockedUsageBlockedAt" // TimeInterval since 1970
        static let lastBlockedUsageEventName = "lastBlockedUsageEventName" // String
        static let lastExtensionRun = "lastExtensionRun" // TimeInterval since 1970
        
        // Unlock session keys (shared with container app)
        static let unlockSessionEndTime = "unlockSessionEndTime"
        static let unlockSessionDuration = "unlockSessionDuration"
        static let unlockSessionUsageThresholdMinutes = "unlockSessionUsageThresholdMinutes"
    }
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // New day started - could reset counters here if needed
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }
    
    // THIS IS THE KEY METHOD - Called when user has used blocked apps for threshold duration
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        // Heartbeat: lets the container app confirm the extension executed.
        if let defaults = screenTimeDefaults {
            defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastExtensionRun)
            defaults.set(event.rawValue, forKey: Keys.lastBlockedUsageEventName)
            defaults.synchronize()
        }

        switch event.rawValue {
        case "UsageStarted":
            // Best-effort "start" signal: this fires quickly once per monitoring interval.
            if let defaults = screenTimeDefaults {
                defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastBlockedUsageStartedAt)
                defaults.synchronize()
            }

        case "TimeLimit":
            // Time limit reached -> block now.
            blockApps()

            // Timestamp when we applied the block.
            if let defaults = screenTimeDefaults {
                defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastBlockedUsageBlockedAt)
            }

            // Clear unlock session state so the container app can reflect the lock instantly next open.
            if let defaults = screenTimeDefaults {
                defaults.removeObject(forKey: Keys.unlockSessionEndTime)
                defaults.removeObject(forKey: Keys.unlockSessionDuration)
                defaults.removeObject(forKey: Keys.unlockSessionUsageThresholdMinutes)
                defaults.synchronize()
            }
            
            // Stop monitoring after we block (prevents repeated callbacks)
            if #available(iOS 15.0, *) {
                DeviceActivityCenter().stopMonitoring([DeviceActivityName("StepBlockerMonitoring")])
            }

        default:
            break
        }
    }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }
    
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
    }
    
    // Block all selected apps by applying shields
    private func blockApps() {
        guard let data = sharedDefaults?.data(forKey: "BlockedAppsSelection"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }
        
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
    }
}
