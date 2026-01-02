import Foundation
import HealthKit

@objc(HealthKitModule)
class HealthKitModule: RCTEventEmitter {
  
  let healthStore = HKHealthStore()
  var observerQuery: HKObserverQuery?
  var isObservingSteps = false
  
  override func supportedEvents() -> [String]! {
    return ["StepUpdate"]
  }
  
  @objc
  func requestPermissions(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    guard HKHealthStore.isHealthDataAvailable() else {
      reject("HEALTH_KIT_NOT_AVAILABLE", "HealthKit is not available on this device", nil)
      return
    }
    
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let typesToRead: Set<HKObjectType> = [stepType]

    healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
      if let error = error {
        reject("PERMISSION_ERROR", "HealthKit permission error: \(error.localizedDescription)", error)
        return
      }

      // For read-only types like stepCount, HealthKit does not expose a reliable
      // authorizationStatus. If there is no error, we treat this as authorized
      // and rely on the user-visible Health settings for control.
      if success {
        resolve(true)
      } else {
        reject("PERMISSION_UNKNOWN", "HealthKit requestAuthorization returned success = false", nil)
      }
    }
  }
  
  @objc
  func checkAuthorizationStatus(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    guard HKHealthStore.isHealthDataAvailable() else {
      reject("HEALTH_KIT_NOT_AVAILABLE", "HealthKit is not available on this device", nil)
      return
    }
    
    // For read-only access (we only read stepCount), HealthKit's
    // authorizationStatus(for:) API reports the *write* permission,
    // which is not what we use. Since we can't reliably query read
    // authorization, we assume that if the user has configured
    // permissions in the Health app, things are OK.
    //
    // The JS side already handles failures in requestPermissions, so here
    // we simply report "true" to unblock onboarding once the user has
    // toggled the setting.
    resolve(true)
  }
  
  @objc
  func getTodaySteps(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
      self.fetchTodaySteps { steps in
          resolve(steps)
      }
  }

  func fetchTodaySteps(completion: @escaping (Int) -> Void) {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    
    let now = Date()
    let startOfDay = Calendar.current.startOfDay(for: now)
    let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
    
    let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
      guard let result = result, let sum = result.sumQuantity() else {
        completion(0)
        return
      }
      
      let steps = sum.doubleValue(for: HKUnit.count())
      completion(Int(steps))
    }
    
    healthStore.execute(query)
  }
    
  @objc
  func startStepObserver() {
      if isObservingSteps { return }
      isObservingSteps = true
      
      let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
      
      // Enable background delivery
      healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
          if let error = error {
              print("Failed to enable background delivery: \(error.localizedDescription)")
          }
      }
      
      observerQuery = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] query, completionHandler, error in
          guard let self = self else { return }
          
          if let error = error {
              print("Observer query failed: \(error.localizedDescription)")
              completionHandler()
              return
          }
          
          // Fetch latest steps and send event
          self.fetchTodaySteps { steps in
              if self.bridge != nil {
                  self.sendEvent(withName: "StepUpdate", body: ["steps": steps])
              }
              completionHandler()
          }
      }
      
      if let query = observerQuery {
          healthStore.execute(query)
      }
  }
    
  @objc
  func stopStepObserver() {
      isObservingSteps = false
      if let query = observerQuery {
          healthStore.stop(query)
          observerQuery = nil
      }
  }

  override static func requiresMainQueueSetup() -> Bool {
    return false
  }
}
