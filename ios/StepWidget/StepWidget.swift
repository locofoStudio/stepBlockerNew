import WidgetKit
import SwiftUI
import UIKit

struct Provider: TimelineProvider {
    let suiteName = "group.com.stepblocker.shared"
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            walletBalance: 160,
            unlockSessionEndTime: 0,
            timeUntilReset: 9600,
            screenDailyAverageSeconds: 12300,
            currentSteps: 4000
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = readData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = readData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    func readData() -> SimpleEntry {
        let userDefaults = UserDefaults(suiteName: suiteName)
        let walletBalance = userDefaults?.integer(forKey: "wallet_balance_minutes") ?? 0
        let unlockSessionEndTime = userDefaults?.double(forKey: "unlock_session_end_time") ?? 0
        let timeUntilReset = userDefaults?.integer(forKey: "time_until_reset_seconds") ?? 0
        let screenDailyAverageSeconds = userDefaults?.integer(forKey: "screen_daily_average_seconds") ?? 0
        let currentSteps = userDefaults?.integer(forKey: "current_steps") ?? 0
        
        return SimpleEntry(
            date: Date(),
            walletBalance: walletBalance,
            unlockSessionEndTime: unlockSessionEndTime,
            timeUntilReset: timeUntilReset,
            screenDailyAverageSeconds: screenDailyAverageSeconds,
            currentSteps: currentSteps
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let walletBalance: Int // Minutes in wallet
    let unlockSessionEndTime: Double // Timestamp when session ends
    let timeUntilReset: Int // Seconds until midnight
    let screenDailyAverageSeconds: Int // 7-day rolling average in seconds
    let currentSteps: Int
}

struct StepWidgetEntryView : View {
    var entry: Provider.Entry
    
    // Helper to format seconds as HH:MM
    func formatHHMM(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
    
    // Helper to format minutes as HH:MM
    func formatMinutes(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }
    
    // Calculate remaining session time in seconds
    var remainingSessionTime: Int {
        if entry.unlockSessionEndTime <= 0 {
            return 0
        }
        let remaining = Int(entry.unlockSessionEndTime) - Int(Date().timeIntervalSince1970)
        return max(0, remaining)
    }
    
    // Check if there's an active unlock session
    var hasActiveSession: Bool {
        entry.unlockSessionEndTime > 0 && entry.unlockSessionEndTime > Date().timeIntervalSince1970
    }

    var body: some View {
        ZStack {
            // Background color matching dashboard
            Color(UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 8) {
                // Top Metrics Row (3 cards)
                HStack(spacing: 6) {
                    // Time Until Reset
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Time Until\nReset")
                            .font(.custom("RobotoMono-Regular", size: 9))
                            .foregroundColor(Color(UIColor(red: 0.59, green: 0.59, blue: 0.59, alpha: 1.0))) // #979797
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(formatHHMM(seconds: entry.timeUntilReset))
                            .font(.custom("RobotoMono-Regular", size: 12))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color(UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0))) // #222
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(UIColor(red: 0.27, green: 0.27, blue: 0.27, alpha: 1.0)), lineWidth: 1) // #444343
                    )
                    
                    // Screen Daily Average
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Screen\nTime")
                            .font(.custom("RobotoMono-Regular", size: 9))
                            .foregroundColor(Color(UIColor(red: 0.59, green: 0.59, blue: 0.59, alpha: 1.0))) // #979797
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(formatHHMM(seconds: entry.screenDailyAverageSeconds))
                            .font(.custom("RobotoMono-Regular", size: 12))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color(UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0))) // #222
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(UIColor(red: 0.27, green: 0.27, blue: 0.27, alpha: 1.0)), lineWidth: 1) // #444343
                    )
                    
                    // Steps Walked
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Steps\nWalked")
                            .font(.custom("RobotoMono-Regular", size: 9))
                            .foregroundColor(Color(UIColor(red: 0.59, green: 0.59, blue: 0.59, alpha: 1.0))) // #979797
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(entry.currentSteps)")
                            .font(.custom("RobotoMono-Regular", size: 12))
                            .foregroundColor(Color(UIColor(red: 0.29, green: 0.96, blue: 0.15, alpha: 1.0))) // #4AF626
                    }
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color(UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0))) // #222
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(UIColor(red: 0.27, green: 0.27, blue: 0.27, alpha: 1.0)), lineWidth: 1) // #444343
                    )
                }
                
                // Main Display Row (2 cards)
                HStack(spacing: 6) {
                    // Time Left (with white border if active)
                    VStack(spacing: 2) {
                        Text("Time Left")
                            .font(.custom("RobotoMono-Regular", size: 9))
                            .foregroundColor(Color(UIColor(red: 0.59, green: 0.59, blue: 0.59, alpha: 1.0))) // #979797
                        Text(formatMinutes(minutes: remainingSessionTime / 60))
                            .font(.custom("RobotoMono-Regular", size: 20))
                            .foregroundColor(Color(UIColor(red: 0.96, green: 0.25, blue: 0.25, alpha: 1.0))) // #F44141
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color(UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0))) // #222
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(hasActiveSession ? Color.white : Color(UIColor(red: 0.44, green: 0.44, blue: 0.44, alpha: 1.0)), lineWidth: hasActiveSession ? 2 : 1) // White if active, #6f6f6f if not
                    )
                    
                    // Time Earned
                    VStack(spacing: 2) {
                        Text("Time Earned")
                            .font(.custom("RobotoMono-Regular", size: 9))
                            .foregroundColor(Color(UIColor(red: 0.59, green: 0.59, blue: 0.59, alpha: 1.0))) // #979797
                        Text(formatMinutes(minutes: entry.walletBalance))
                            .font(.custom("RobotoMono-Regular", size: 20))
                            .foregroundColor(Color(UIColor(red: 0.96, green: 0.43, blue: 0.25, alpha: 1.0))) // #F46E41
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color(UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0))) // #222
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color(UIColor(red: 0.44, green: 0.44, blue: 0.44, alpha: 1.0)), lineWidth: 1) // #6f6f6f
                    )
                }
            }
            .padding(8)
        }
    }
}

@main
struct StepWidget: Widget {
    let kind: String = "StepWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StepWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Step Blocker")
        .description("Track your steps and blocked apps.")
        .supportedFamilies([.systemSmall])
    }
}
