//
// DeviceActivityMonitorExtension.swift
// StepBlockerMonitor
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    
    let store = ManagedSettingsStore()
    // UNIFIED APP GROUP ID - MUST MATCH MAIN APP
    let defaults = UserDefaults(suiteName: "group.com.locofoStudio.stepblocker")
    
    private enum Keys {
        static let lastExtensionRun = "lastExtensionRun"
        static let lastBlockedUsageEventName = "lastBlockedUsageEventName"
        static let unlockSessionEndTime = "unlockSessionEndTime"
    }
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Ensure shields are correct when monitoring starts
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Ensure shields are correct when monitoring ends
    }
    
    // THIS IS CALLED WHEN THE TIME LIMIT IS REACHED
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        // Log for debugging
        if let defaults = defaults {
            defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastExtensionRun)
            defaults.set(event.rawValue, forKey: Keys.lastBlockedUsageEventName)
            defaults.synchronize()
        }
        
        // If the event is "TimeLimit", it means the user's unlocked time is UP.
        // We must RE-BLOCK the apps now.
        if event.rawValue == "TimeLimit" {
            blockApps()
            
            // Clear the session flags so the main app knows the session is over
            defaults?.removeObject(forKey: Keys.unlockSessionEndTime)
            defaults?.synchronize()
            
            // Stop monitoring to save resources
             let center = DeviceActivityCenter()
             center.stopMonitoring([DeviceActivityName("StepBlockerMonitoring")])
        }
    }
    
    // Helper to Apply Shields (Block Apps)
    private func blockApps() {
        guard let data = defaults?.data(forKey: "BlockedAppsSelection"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }
        
        // Apply Shields
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
    }
}
