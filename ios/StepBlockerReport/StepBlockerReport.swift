import DeviceActivity
import SwiftUI
import FamilyControls
import ManagedSettings

// MARK: - Main Extension Entry Point

@main
struct StepBlockerReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        StepBlockerActivityScene { totalActivityString in
            StepBlockerTimerView(activityMinutes: totalActivityString)
        }
    }
}

// MARK: - Activity Scene (calculates usage and handles blocking)

struct StepBlockerActivityScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init("TotalActivity")
    let content: (String) -> StepBlockerTimerView
    
    // Shared UserDefaults for app selection
    private let sharedDefaults = UserDefaults(suiteName: "group.com.stepblocker.shared")
    // Shared UserDefaults for screen time data
    private let screenTimeDefaults = UserDefaults(suiteName: "group.com.locofoStudio.stepblocker")
    // ManagedSettingsStore for blocking apps
    private let store = ManagedSettingsStore()
    
    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> String {
        // Log that the extension is running
        NSLog("[StepBlockerReport] 🚀 makeConfiguration called!")
        
        // Always write a heartbeat so the container app can confirm the extension executed
        screenTimeDefaults?.set(Date().timeIntervalSince1970, forKey: "lastExtensionRun")
        screenTimeDefaults?.synchronize()
        
        var totalDuration: TimeInterval = 0
        var totalScreenTimeDuration: TimeInterval = 0 // Total screen time across ALL apps
        
        // Load the blocked apps selection
        var selectedAppTokens: Set<ApplicationToken> = []
        var selectedCategoryTokens: Set<ActivityCategoryToken> = []
        var selection: FamilyActivitySelection?
        
        // Debug: Check if we can access UserDefaults
        if sharedDefaults == nil {
            NSLog("[StepBlockerReport] ❌ sharedDefaults is nil! Cannot access group.com.stepblocker.shared")
        }
        if screenTimeDefaults == nil {
            NSLog("[StepBlockerReport] ❌ screenTimeDefaults is nil! Cannot access group.com.locofoStudio.stepblocker")
        }
        
        if let savedData = sharedDefaults?.data(forKey: "BlockedAppsSelection"),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: savedData) {
            selection = decoded
            selectedAppTokens = Set(decoded.applicationTokens)
            selectedCategoryTokens = Set(decoded.categoryTokens)
            NSLog("[StepBlockerReport] ✅ Loaded \(selectedAppTokens.count) apps, \(selectedCategoryTokens.count) categories")
        } else {
            NSLog("[StepBlockerReport] ⚠️ No BlockedAppsSelection found in sharedDefaults")
        }
        
        // Iterate through activity data
        // Calculate both: blocked app usage AND total screen time (all apps)
        for await activityData in data {
            for await segment in activityData.activitySegments {
                // Total screen time for the segment (all apps) — this is the closest match to iOS “Screen Time”
                totalScreenTimeDuration += segment.totalActivityDuration

                for await categoryActivity in segment.categories {
                    // Check if entire category is blocked
                    var categoryMatched = false
                    if let token = categoryActivity.category.token {
                        if selectedCategoryTokens.contains(token) {
                            totalDuration += categoryActivity.totalActivityDuration
                            categoryMatched = true
                        }
                    }
                    
                    // If category not blocked, check individual apps
                    if !categoryMatched {
                        for await appActivity in categoryActivity.applications {
                            if let token = appActivity.application.token {
                                if selectedAppTokens.contains(token) {
                                    totalDuration += appActivity.totalActivityDuration
                                }
                            }
                        }
                    }
                }
            }
        }
        
        let usedMinutes = Int(totalDuration / 60)
        let totalScreenTimeSeconds = Int(totalScreenTimeDuration)
        let earnedMinutes = screenTimeDefaults?.integer(forKey: "dailyLimitMinutes") ?? 0
        let remainingMinutes = max(0, earnedMinutes - usedMinutes)
        
        // Write used minutes to UserDefaults
        screenTimeDefaults?.set(usedMinutes, forKey: "usedMinutes")
        // Write total screen time to UserDefaults
        screenTimeDefaults?.set(totalScreenTimeSeconds, forKey: "totalScreenTimeToday")
        screenTimeDefaults?.set(Date().timeIntervalSince1970, forKey: "totalScreenTimeLastUpdate")
        // Write timestamp to verify extension is running
        screenTimeDefaults?.set(Date().timeIntervalSince1970, forKey: "lastExtensionRun")
        screenTimeDefaults?.synchronize()
        
        NSLog("[StepBlockerReport] 📊 earned=\(earnedMinutes), used=\(usedMinutes), remaining=\(remainingMinutes), totalDuration=\(totalDuration)sec")
        NSLog("[StepBlockerReport] 📱 Total screen time: \(totalScreenTimeSeconds) seconds")
        NSLog("[StepBlockerReport] ✅ Wrote usedMinutes=\(usedMinutes) and totalScreenTime=\(totalScreenTimeSeconds) to UserDefaults")
        
        // AUTO-BLOCK: If time is exhausted, block the apps directly from the extension
        if remainingMinutes <= 0 && earnedMinutes > 0 {
            if let sel = selection {
                store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
                store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(sel.categoryTokens)
                store.shield.webDomains = sel.webDomainTokens
                print("[StepBlockerReport] ⛔ Time exhausted - BLOCKED apps")
            }
        }
        
        return "\(usedMinutes)"
    }
}

// MARK: - Timer View (displayed in the report)

struct StepBlockerTimerView: View {
    let activityMinutes: String
    
    @AppStorage("dailyLimitMinutes", store: UserDefaults(suiteName: "group.com.locofoStudio.stepblocker"))
    var limitMinutes: Int = 0
    
    var body: some View {
        let used = Int(activityMinutes) ?? 0
        let remaining = max(0, limitMinutes - used)
        let hours = remaining / 60
        let minutes = remaining % 60
        
        VStack {
            Text("Remaining")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(String(format: "%02d:%02d", hours, minutes))
                .font(.system(size: 24, weight: .bold))
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}
