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
        // Check if session has expired and block immediately
        checkAndBlockIfExpired()
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Ensure shields are correct when monitoring ends
        checkAndBlockIfExpired()
    }
    
    // Check if unlock session has expired and block apps immediately
    private func checkAndBlockIfExpired() {
        guard let defaults = defaults,
              let endTimeData = defaults.object(forKey: Keys.unlockSessionEndTime) as? Date else {
            // No active session, ensure apps are blocked
            blockApps()
            return
        }
        
        // If session has expired, block immediately
        if Date() >= endTimeData {
            NSLog("[DeviceActivityMonitor] Session expired, blocking apps immediately")
            blockApps()
            defaults.removeObject(forKey: Keys.unlockSessionEndTime)
            defaults.synchronize()
            
            // Stop monitoring to save resources
            let center = DeviceActivityCenter()
            center.stopMonitoring([DeviceActivityName("StepBlockerMonitoring")])
        }
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
        // We must RE-BLOCK the apps now, even if user is currently in the app.
        if event.rawValue == "TimeLimit" {
            NSLog("[DeviceActivityMonitor] TimeLimit threshold reached, blocking apps immediately")
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
    // This immediately blocks apps, even if user is currently using them
    private func blockApps() {
        guard let data = defaults?.data(forKey: "BlockedAppsSelection"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            NSLog("[DeviceActivityMonitor] No app selection found, cannot block")
            return
        }
        
        // Apply Shields immediately - this will block apps even if user is currently in them
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
        
        NSLog("[DeviceActivityMonitor] ✅ Apps blocked immediately - shields applied to \(selection.applicationTokens.count) apps")
    }
}
