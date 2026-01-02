import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import SwiftUI
import UserNotifications

@objc(BlockerModule)
class BlockerModule: NSObject {
  
  let store = ManagedSettingsStore()
  let userDefaults = UserDefaults(suiteName: "group.com.locofoStudio.stepblocker") ?? .standard
  let activityCenter = DeviceActivityCenter()
  
  // Schedule name for DeviceActivity monitoring
  private let scheduleName = DeviceActivityName("StepBlockerMonitoring")
  
  @objc
  func requestAuthorization(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    if #available(iOS 15.0, *) {
      DispatchQueue.main.async {
        Task {
          do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            let status = AuthorizationCenter.shared.authorizationStatus
            if status == .approved {
              resolve(true)
            } else {
              reject("AUTH_NOT_APPROVED", "Family Controls authorization was not approved", nil)
            }
          } catch {
            reject("AUTH_ERROR", "Failed to request authorization: \(error.localizedDescription)", error)
          }
        }
      }
    } else {
      reject("OS_VERSION", "Requires iOS 15.0+", nil)
    }
  }
  
  @objc
  func presentAppPicker(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    if #available(iOS 15.0, *) {
      DispatchQueue.main.async {
        var window: UIWindow?
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
          window = windowScene.windows.first(where: { $0.isKeyWindow })
        }
        
        if window == nil {
          window = UIApplication.shared.delegate?.window as? UIWindow
        }
        
        guard let window = window,
              let rootViewController = window.rootViewController else {
          reject("NO_ROOT_VIEW_CONTROLLER", "Could not find root view controller", nil)
          return
        }
        
        var selection = FamilyActivitySelection()
        if let data = self.userDefaults.data(forKey: "BlockedAppsSelection"),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
          selection = decoded
        }
        
        class SelectionContainer: ObservableObject {
            @Published var selection: FamilyActivitySelection
            init(selection: FamilyActivitySelection) {
                self.selection = selection
            }
        }
        
        let container = SelectionContainer(selection: selection)
        
        let pickerBinding = Binding<FamilyActivitySelection>(
            get: { container.selection },
            set: { newSelection in
                container.selection = newSelection
                if let data = try? JSONEncoder().encode(newSelection) {
                    self.userDefaults.set(data, forKey: "BlockedAppsSelection")
                }
            }
        )
        
        let picker = ActivityPicker(selection: pickerBinding) {
            rootViewController.dismiss(animated: true)
            let count = container.selection.applicationTokens.count + 
                       container.selection.categoryTokens.count + 
                       container.selection.webDomainTokens.count
            resolve(count)
        }
        
        let hostingController = UIHostingController(rootView: picker)
        hostingController.modalPresentationStyle = .formSheet
        rootViewController.present(hostingController, animated: true)
      }
    } else {
      reject("OS_VERSION", "Requires iOS 15.0+", nil)
    }
  }
  
  @objc
  func setBlockedApps(_ bundleIds: [String]) {
      print("BlockerModule: setBlockedApps called with \(bundleIds) - ignoring in favor of FamilyControls")
  }
  
  @objc
  func toggleBlocking(_ enabled: Bool) {
    if #available(iOS 15.0, *) {
      if enabled {
        // Block apps: Apply shields and stop monitoring
        if let data = userDefaults.data(forKey: "BlockedAppsSelection"),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            
            let applications = selection.applicationTokens
            let categories = selection.categoryTokens
            
            store.shield.applications = applications.isEmpty ? nil : applications
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(categories)
            store.shield.webDomains = selection.webDomainTokens
            NSLog("[BlockerModule] ⛔ Blocked \(applications.count) apps, \(categories.count) categories")
        }
        stopMonitoring()
      } else {
        // Unblock apps: Remove shields and start monitoring
        store.clearAllSettings()
        NSLog("[BlockerModule] ✅ Unblocked apps")
        // Don't start monitoring here - wait for setRemainingTime to be called with correct value
      }
    }
  }
  
  // Set remaining time and start monitoring with correct threshold
  @objc
  func setRemainingTime(_ minutes: Int) {
    if #available(iOS 15.0, *) {
      NSLog("[BlockerModule] setRemainingTime called with \(minutes) minutes")
      startMonitoringWithThreshold(minutes)
    }
  }
  
  // Start DeviceActivity monitoring with threshold passed from React Native
  private func startMonitoringWithThreshold(_ remainingMinutes: Int) {
    if #available(iOS 15.0, *) {
      userDefaults.synchronize()
      
      guard let data = userDefaults.data(forKey: "BlockedAppsSelection"),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
        NSLog("[BlockerModule] No app selection found")
        return
      }
      
      let applications = selection.applicationTokens
      let categories = selection.categoryTokens
      
      guard !applications.isEmpty || !categories.isEmpty else {
        NSLog("[BlockerModule] No apps or categories selected")
        return
      }
      
      let threshold = max(1, remainingMinutes)
      
      NSLog("[BlockerModule] Setting up monitoring with threshold=\(threshold)min")
      
      // Schedule runs all day
      let schedule = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0),
        intervalEnd: DateComponents(hour: 23, minute: 59),
        repeats: true,
        warningTime: nil
      )
      
      // Create threshold event - when user uses blocked apps for this long, monitor extension triggers
      let thresholdEvent = DeviceActivityEvent(
        applications: applications,
        categories: categories,
        webDomains: selection.webDomainTokens,
        threshold: DateComponents(minute: threshold)
      )

      // "Usage started" event: fires quickly (once per interval) when blocked apps are first used.
      // Note: iOS DeviceActivity does not provide per-foreground/background callbacks for third-party apps.
      let usageStartedEvent = DeviceActivityEvent(
        applications: applications,
        categories: categories,
        webDomains: selection.webDomainTokens,
        threshold: DateComponents(second: 1)
      )
      
      // Stop any existing monitoring first
      activityCenter.stopMonitoring([scheduleName])
      
      do {
        // Start monitoring with the threshold
        try activityCenter.startMonitoring(
          scheduleName,
          during: schedule,
          events: [
            DeviceActivityEvent.Name("UsageStarted"): usageStartedEvent,
            DeviceActivityEvent.Name("TimeLimit"): thresholdEvent
          ]
        )
        NSLog("[BlockerModule] ✅ Started monitoring with \(threshold)min threshold")
      } catch {
        NSLog("[BlockerModule] ❌ Failed to start monitoring: \(error.localizedDescription)")
      }
    }
  }
  
  private func stopMonitoring() {
    if #available(iOS 15.0, *) {
      activityCenter.stopMonitoring([scheduleName])
      print("[BlockerModule] Stopped activity monitoring")
    }
  }
  
  // MARK: - Vending Machine Logic
  
  private enum SessionKeys {
    static let walletBalance = "walletBalance"
    static let unlockSessionEndTime = "unlockSessionEndTime"
    static let unlockSessionDuration = "unlockSessionDuration"
    // Absolute usage threshold (in minutes) for blocked apps for TODAY when session should end.
    // We set this to: currentUsedMinutesToday + purchasedMinutes
    static let unlockSessionUsageThresholdMinutes = "unlockSessionUsageThresholdMinutes"
    static let usedMinutes = "usedMinutes"
  }

  private enum SBNotificationIds {
    static let sessionStarted = "StepBlocker.session_started"
    static let twoMinWarning = "StepBlocker.two_min_warning"
    static let timesUp = "StepBlocker.times_up"
    static let sessionCancelledEarly = "StepBlocker.session_cancelled_early"
  }

  private func cancelSessionNotifications() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: [
        SBNotificationIds.sessionStarted,
        SBNotificationIds.twoMinWarning,
        SBNotificationIds.timesUp,
        SBNotificationIds.sessionCancelledEarly
      ]
    )
  }

  private func scheduleUnlockNotifications(endTime: Date, durationMinutes: Int) {
    let center = UNUserNotificationCenter.current()
    cancelSessionNotifications()

    // A1 – Session started ✅ (fires immediately)
    do {
      let content = UNMutableNotificationContent()
      content.title = "Session started ✅"
      content.body = "You unlocked \(durationMinutes) minutes. Enjoy it—and remember, every step earns more time."
      content.sound = .default
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
      let req = UNNotificationRequest(identifier: SBNotificationIds.sessionStarted, content: content, trigger: trigger)
      center.add(req)
    }

    // A2 – 2-minute warning
    let warningTime = endTime.addingTimeInterval(-120)
    if warningTime > Date() {
      let content = UNMutableNotificationContent()
      content.title = "2 minutes left ⏳"
      content.body = "Wrap things up—your StepBlocker session is ending soon. Walk a bit more to top up your time."
      content.sound = .default
      let trigger = UNCalendarNotificationTrigger(
        dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: warningTime),
        repeats: false
      )
      let req = UNNotificationRequest(identifier: SBNotificationIds.twoMinWarning, content: content, trigger: trigger)
      center.add(req)
    }

    // A3 – Time’s up
    do {
      let content = UNMutableNotificationContent()
      content.title = "Time’s up! 🔒"
      content.body = "Your session just ended and apps are locked again. You protected your focus—walk to earn your next round."
      content.sound = .default
      let trigger = UNCalendarNotificationTrigger(
        dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: endTime),
        repeats: false
      )
      let req = UNNotificationRequest(identifier: SBNotificationIds.timesUp, content: content, trigger: trigger)
      center.add(req)
    }
  }

  private func scheduleSessionCancelledEarlyNotification(refundedMinutes: Int) {
    let center = UNUserNotificationCenter.current()
    // A4 – Session cancelled early (fires immediately)
    let content = UNMutableNotificationContent()
    content.title = "Nice save 🙌"
    content.body = "You ended your session early. \(refundedMinutes) minutes were sent back to your time bank."
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let req = UNNotificationRequest(identifier: SBNotificationIds.sessionCancelledEarly, content: content, trigger: trigger)
    center.add(req)
  }
  
  @objc
  func unlockApps(_ minutes: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    if #available(iOS 15.0, *) {
      let unlockMinutes = Int(truncating: minutes)
      let suiteName = "group.com.locofoStudio.stepblocker"
      guard let defaults = UserDefaults(suiteName: suiteName) else {
        reject("USERDEFAULTS_ERROR", "Could not access UserDefaults suite", nil)
        return
      }
      
      // 1. Check if user can afford it
      let currentBalance = defaults.integer(forKey: SessionKeys.walletBalance)
      guard currentBalance >= unlockMinutes else {
        reject("INSUFFICIENT_BALANCE", "Not enough steps! You need \(unlockMinutes) minutes but only have \(currentBalance)", nil)
        return
      }
      
      // 2. Deduct "Money"
      let newBalance = currentBalance - unlockMinutes
      defaults.set(newBalance, forKey: SessionKeys.walletBalance)
      
      // 3. Set Session State
      let endTime = Date().addingTimeInterval(TimeInterval(unlockMinutes * 60))
      defaults.set(endTime, forKey: SessionKeys.unlockSessionEndTime)
      defaults.set(unlockMinutes, forKey: SessionKeys.unlockSessionDuration)
      
      // IMPORTANT: Start DeviceActivity monitoring so the monitor extension can re-block immediately,
      // even if the user never returns to the StepBlocker app.
      // DeviceActivity thresholds are based on *total usage today*, so we compute an absolute target:
      let usedSoFar = defaults.integer(forKey: SessionKeys.usedMinutes)
      let absoluteThreshold = max(1, usedSoFar + unlockMinutes)
      defaults.set(absoluteThreshold, forKey: SessionKeys.unlockSessionUsageThresholdMinutes)
      defaults.synchronize()
      
      // 4. UNBLOCK APPS (Clear the Shield)
      store.clearAllSettings()
      NSLog("[BlockerModule] ✅ Unlocked apps for \(unlockMinutes) minutes. New balance: \(newBalance)")
      
      // Start monitoring for the absolute threshold (usage today) so the extension can block instantly.
      startMonitoringWithThreshold(absoluteThreshold)
      NSLog("[BlockerModule] 📟 Monitoring until usedMinutes reaches \(absoluteThreshold) (was \(usedSoFar))")
      
      // 5. Schedule Notifications (native, so it fires in background)
      scheduleUnlockNotifications(endTime: endTime, durationMinutes: unlockMinutes)
      
      resolve([
        "balance": newBalance,
        "endTime": endTime.timeIntervalSince1970,
        "usageThresholdMinutes": absoluteThreshold,
        "usedMinutesAtPurchase": usedSoFar
      ])
    } else {
      reject("OS_VERSION", "Requires iOS 15.0+", nil)
    }
  }
  
  @objc
  func endSessionEarly(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    if #available(iOS 15.0, *) {
      let suiteName = "group.com.locofoStudio.stepblocker"
      guard let defaults = UserDefaults(suiteName: suiteName) else {
        reject("USERDEFAULTS_ERROR", "Could not access UserDefaults suite", nil)
        return
      }
      
      guard let endTime = defaults.object(forKey: SessionKeys.unlockSessionEndTime) as? Date else {
        reject("NO_SESSION", "No active unlock session", nil)
        return
      }
      
      // 1. Calculate Refund
      let remaining = endTime.timeIntervalSinceNow
      var refundedMinutes = 0
      if remaining > 60 { // Only refund if > 1 minute left
        refundedMinutes = Int(remaining / 60)
        let currentBalance = defaults.integer(forKey: SessionKeys.walletBalance)
        defaults.set(currentBalance + refundedMinutes, forKey: SessionKeys.walletBalance)
        NSLog("[BlockerModule] 💰 Refunded \(refundedMinutes) minutes. New balance: \(currentBalance + refundedMinutes)")
      }
      
      // 2. Re-Block Immediately
      // Restore the saved selection from UserDefaults
      if let data = defaults.data(forKey: "BlockedAppsSelection"),
         let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
        NSLog("[BlockerModule] ⛔ Re-blocked apps after early end")
      }
      
      // 3. Clear Session
      defaults.removeObject(forKey: SessionKeys.unlockSessionEndTime)
      defaults.removeObject(forKey: SessionKeys.unlockSessionDuration)
      defaults.removeObject(forKey: SessionKeys.unlockSessionUsageThresholdMinutes)
      defaults.synchronize()

      // 4. Cancel session notifications + optionally notify refund
      cancelSessionNotifications()
      if refundedMinutes > 0 {
        scheduleSessionCancelledEarlyNotification(refundedMinutes: refundedMinutes)
      }
      
      // Stop monitoring once session ends
      stopMonitoring()
      
      resolve(["refunded": refundedMinutes])
    } else {
      reject("OS_VERSION", "Requires iOS 15.0+", nil)
    }
  }
  
  @objc
  func getWalletBalance(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let suiteName = "group.com.locofoStudio.stepblocker"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      reject("USERDEFAULTS_ERROR", "Could not access UserDefaults suite", nil)
      return
    }
    
    let balance = defaults.integer(forKey: SessionKeys.walletBalance)
    let endTime = defaults.object(forKey: SessionKeys.unlockSessionEndTime) as? Date
    let sessionDuration = defaults.integer(forKey: SessionKeys.unlockSessionDuration)
    let usageThreshold = defaults.integer(forKey: SessionKeys.unlockSessionUsageThresholdMinutes)
    
    resolve([
      "balance": balance,
      "hasActiveSession": endTime != nil && endTime! > Date(),
      "sessionEndTime": endTime?.timeIntervalSince1970 ?? 0,
      "sessionDuration": sessionDuration,
      "usageThresholdMinutes": usageThreshold
    ])
  }
  
  @objc
  func addToWalletBalance(_ minutes: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let suiteName = "group.com.locofoStudio.stepblocker"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      reject("USERDEFAULTS_ERROR", "Could not access UserDefaults suite", nil)
      return
    }
    
    let minutesToAdd = Int(truncating: minutes)
    let currentBalance = defaults.integer(forKey: SessionKeys.walletBalance)
    let newBalance = max(0, currentBalance + minutesToAdd) // Prevent negative balance
    defaults.set(newBalance, forKey: SessionKeys.walletBalance)
    defaults.synchronize()
    
    NSLog("[BlockerModule] 💰 Added \(minutesToAdd) minutes to wallet. New balance: \(newBalance)")
    resolve(["balance": newBalance])
  }
  
  @objc
  func resetWalletBalance(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let suiteName = "group.com.locofoStudio.stepblocker"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      reject("USERDEFAULTS_ERROR", "Could not access UserDefaults suite", nil)
      return
    }
    
    defaults.set(0, forKey: SessionKeys.walletBalance)
    defaults.removeObject(forKey: SessionKeys.unlockSessionEndTime)
    defaults.removeObject(forKey: SessionKeys.unlockSessionDuration)
    defaults.removeObject(forKey: SessionKeys.unlockSessionUsageThresholdMinutes)
    defaults.synchronize()
    
    NSLog("[BlockerModule] 🔄 Reset wallet balance to 0")
    resolve(["balance": 0])
  }
  
  @objc
  static func requiresMainQueueSetup() -> Bool {
    return true
  }
}

