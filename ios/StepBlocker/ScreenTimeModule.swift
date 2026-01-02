import Foundation
import React
import DeviceActivity

@objc(ScreenTimeModule)
class ScreenTimeModule: NSObject, RCTBridgeModule {
  // React Native module name
  static func moduleName() -> String! {
    return "ScreenTimeModule"
  }

  @objc static func requiresMainQueueSetup() -> Bool {
    return false
  }

  private let suiteName = "group.com.locofoStudio.stepblocker"
  private let limitKey = "dailyLimitMinutes"
  private let usedKey = "usedMinutes"
  private let blockedUsageStartedAtKey = "lastBlockedUsageStartedAt"
  private let blockedUsageBlockedAtKey = "lastBlockedUsageBlockedAt"
  private let blockedUsageEventNameKey = "lastBlockedUsageEventName"

  @objc(saveDailyLimit:)
  func saveDailyLimit(_ minutes: NSNumber) {
    let rounded = Int(truncating: minutes)
    if let defaults = UserDefaults(suiteName: suiteName) {
      defaults.set(rounded, forKey: limitKey)
      defaults.synchronize()
      NSLog("[ScreenTimeModule] Saved dailyLimitMinutes=\(rounded) to suite \(suiteName)")
    } else {
      NSLog("[ScreenTimeModule] ERROR: Could not access UserDefaults suite \(suiteName)")
    }
  }
  
  @objc(getUsedMinutes:reject:)
  func getUsedMinutes(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    if let defaults = UserDefaults(suiteName: suiteName) {
      defaults.synchronize()
      let used = defaults.integer(forKey: usedKey)
      resolve(used)
    } else {
      reject("USERDEFAULTS_ERROR", "Could not access UserDefaults suite \(suiteName)", nil)
    }
  }
  
  // Returns detailed extension status for debugging
  @objc(getExtensionStatus:reject:)
  func getExtensionStatus(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    var status: [String: Any] = [:]
    
    if let defaults = UserDefaults(suiteName: suiteName) {
      defaults.synchronize()
      status["usedMinutes"] = defaults.integer(forKey: usedKey)
      status["dailyLimit"] = defaults.integer(forKey: limitKey)
      
      let lastRun = defaults.double(forKey: "lastExtensionRun")
      if lastRun > 0 {
        let secondsAgo = Int(Date().timeIntervalSince1970 - lastRun)
        status["extensionLastRan"] = secondsAgo
        status["extensionHasRun"] = true
      } else {
        status["extensionLastRan"] = -1
        status["extensionHasRun"] = false
      }

      // Best-effort timestamps emitted by StepBlockerMonitor extension.
      let startedAt = defaults.double(forKey: blockedUsageStartedAtKey)
      status["blockedUsageStartedAt"] = startedAt > 0 ? startedAt : NSNull()

      let blockedAt = defaults.double(forKey: blockedUsageBlockedAtKey)
      status["blockedUsageBlockedAt"] = blockedAt > 0 ? blockedAt : NSNull()

      let lastEvent = defaults.string(forKey: blockedUsageEventNameKey)
      status["blockedUsageLastEvent"] = lastEvent ?? NSNull()
    }
    
    if let sharedDefaults = UserDefaults(suiteName: "group.com.stepblocker.shared") {
      if let data = sharedDefaults.data(forKey: "BlockedAppsSelection") {
        status["blockedAppsSelectionBytes"] = data.count
      } else {
        status["blockedAppsSelectionBytes"] = 0
      }
    }
    
    resolve(status)
  }

  // Convenience API for the app: returns timestamps written by extensions.
  @objc(getBlockedUsageTimestamps:reject:)
  func getBlockedUsageTimestamps(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      reject("USERDEFAULTS_ERROR", "Could not access UserDefaults suite \(suiteName)", nil)
      return
    }

    defaults.synchronize()
    let startedAt = defaults.double(forKey: blockedUsageStartedAtKey)
    let blockedAt = defaults.double(forKey: blockedUsageBlockedAtKey)
    let lastEvent = defaults.string(forKey: blockedUsageEventNameKey)

    var result: [String: Any] = [:]
    result["startedAt"] = startedAt > 0 ? startedAt : NSNull()
    result["blockedAt"] = blockedAt > 0 ? blockedAt : NSNull()
    result["lastEvent"] = lastEvent ?? NSNull()
    
    resolve(result)
  }
  
  // Get total screen time for today (in seconds)
  // Note: iOS doesn't provide direct API for total screen time, so we'll use DeviceActivityReport
  // For now, we'll return a cached value or calculate from DeviceActivity if available
  @objc(getTotalScreenTime:reject:)
  func getTotalScreenTime(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    if #available(iOS 15.0, *) {
      // Try to get from cached value first
      if let defaults = UserDefaults(suiteName: suiteName) {
        defaults.synchronize()
        let cachedTotal = defaults.double(forKey: "totalScreenTimeToday")
        let lastUpdate = defaults.double(forKey: "totalScreenTimeLastUpdate")
        
        // If cached value is from today, return it
        let today = Calendar.current.startOfDay(for: Date())
        if lastUpdate >= today.timeIntervalSince1970 {
          let totalSeconds = Int(cachedTotal)
          resolve(totalSeconds)
          return
        }
      }
      
      // If no cached value or it's outdated, we need to calculate it
      // DeviceActivityReport would be needed here, but that's complex
      // For now, return 0 and let the app track it
      resolve(0)
    } else {
      reject("OS_VERSION", "Requires iOS 15.0+", nil)
    }
  }
  
  // Save total screen time (called by DeviceActivityReport extension or app tracking)
  @objc(saveTotalScreenTime:)
  func saveTotalScreenTime(_ seconds: NSNumber) {
    if let defaults = UserDefaults(suiteName: suiteName) {
      defaults.set(seconds.doubleValue, forKey: "totalScreenTimeToday")
      defaults.set(Date().timeIntervalSince1970, forKey: "totalScreenTimeLastUpdate")
      defaults.synchronize()
      NSLog("[ScreenTimeModule] Saved totalScreenTime=\(seconds) seconds")
    }
  }
}
