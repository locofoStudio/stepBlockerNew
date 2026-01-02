import Foundation
import WidgetKit

@objc(WidgetBridgeModule)
class WidgetBridgeModule: NSObject {
  
  let suiteName = "group.com.stepblocker.shared"
  
  @objc
  func updateWidgetData(
    _ walletBalance: Double,
    _ unlockSessionEndTime: Double,
    _ timeUntilReset: Double,
    _ screenDailyAverageSeconds: Double,
    _ currentSteps: Double
  ) {
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
      print("[WidgetBridgeModule] Warning: Could not access App Group UserDefaults")
      return
    }
    
    // Dashboard data
    userDefaults.set(Int(walletBalance), forKey: "wallet_balance_minutes")
    userDefaults.set(unlockSessionEndTime > 0 ? unlockSessionEndTime : 0, forKey: "unlock_session_end_time")
    userDefaults.set(Int(timeUntilReset), forKey: "time_until_reset_seconds")
    userDefaults.set(Int(screenDailyAverageSeconds), forKey: "screen_daily_average_seconds")
    userDefaults.set(Int(currentSteps), forKey: "current_steps")
    userDefaults.set(Date(), forKey: "last_updated_date")
    userDefaults.synchronize()
    
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadTimelines(ofKind: "StepWidget")
    }
  }
  
  @objc
  static func requiresMainQueueSetup() -> Bool {
    return false
  }
}

