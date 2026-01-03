import SwiftUI
import DeviceActivity
import UIKit

/// SwiftUI view that embeds DeviceActivityReport to trigger the extension
@available(iOS 16.0, *)
struct DeviceActivityReportViewWrapper: View {
    // Filter for the report - uses the "TotalActivity" context from StepBlockerReport
    var filter: DeviceActivityFilter {
        DeviceActivityFilter(
            segment: .daily(
                during: Calendar.current.dateInterval(of: .day, for: Date())!
            )
        )
    }
    
    var context: DeviceActivityReport.Context {
        .init("TotalActivity")
    }
    
    var body: some View {
        // This view triggers the StepBlockerReportExtension's makeConfiguration
        DeviceActivityReport(context, filter: filter)
            .frame(width: 1, height: 1) // Minimal size - we just need it to trigger the extension
            .opacity(0.01) // Nearly invisible
    }
}

/// UIKit wrapper for the SwiftUI view
@available(iOS 16.0, *)
class DeviceActivityReportViewController: UIViewController {
    private var currentHostingController: UIHostingController<DeviceActivityReportViewWrapper>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // CRITICAL: Disable user interaction on the main view so it doesn't block touches
        view.isUserInteractionEnabled = false
        
        // Initial setup
        addReportView()
        
        // Refresh every 30 seconds to update usedMinutes
        // This triggers the extension's makeConfiguration
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refreshReportView()
        }
    }
    
    private func addReportView() {
        if #available(iOS 16.0, *) {
            let hostingController = UIHostingController(rootView: DeviceActivityReportViewWrapper())
            addChild(hostingController)
            view.addSubview(hostingController.view)
            hostingController.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
            // CRITICAL: Disable user interaction so this view doesn't block touches
            hostingController.view.isUserInteractionEnabled = false
            hostingController.didMove(toParent: self)
            currentHostingController = hostingController
        }
    }
    
    private func refreshReportView() {
        // Remove current view
        currentHostingController?.willMove(toParent: nil)
        currentHostingController?.view.removeFromSuperview()
        currentHostingController?.removeFromParent()
        currentHostingController = nil
        
        // Add fresh view to trigger extension
        addReportView()
        print("[DeviceActivityReport] Refreshed report view")
    }
}

/// React Native module to embed the DeviceActivityReport view
@objc(DeviceActivityReportBridge)
class DeviceActivityReportBridge: NSObject {
    
    private var reportViewController: UIViewController?
    
    @objc
    func startReportTracking() {
        NSLog("[DeviceActivityReportBridge] startReportTracking called")
        
        if #available(iOS 16.0, *) {
            DispatchQueue.main.async {
                NSLog("[DeviceActivityReportBridge] Looking for root VC...")
                
                guard let window = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap({ $0.windows })
                    .first(where: { $0.isKeyWindow }),
                      let rootVC = window.rootViewController else {
                    NSLog("[DeviceActivityReportBridge] ❌ No root view controller found")
                    return
                }
                
                NSLog("[DeviceActivityReportBridge] Found root VC, adding report view")
                
                // Remove existing if any
                self.reportViewController?.willMove(toParent: nil)
                self.reportViewController?.view.removeFromSuperview()
                self.reportViewController?.removeFromParent()
                
                // DISABLED: Add the report view controller as a child
                // This was blocking touches - completely disabled for now
                /*
                let reportVC = DeviceActivityReportViewController()
                rootVC.addChild(reportVC)
                rootVC.view.addSubview(reportVC.view)
                reportVC.view.frame = CGRect(x: -100, y: -100, width: 1, height: 1)
                reportVC.view.isUserInteractionEnabled = false
                reportVC.didMove(toParent: rootVC)
                
                self.reportViewController = reportVC
                */
                NSLog("[DeviceActivityReportBridge] ✅ Report tracking DISABLED")
            }
        } else {
            NSLog("[DeviceActivityReportBridge] ❌ iOS 16.0+ required for DeviceActivityReport")
        }
    }
    
    @objc
    func stopReportTracking() {
        NSLog("[DeviceActivityReportBridge] stopReportTracking called")
        DispatchQueue.main.async {
            self.reportViewController?.willMove(toParent: nil)
            self.reportViewController?.view.removeFromSuperview()
            self.reportViewController?.removeFromParent()
            self.reportViewController = nil
            NSLog("[DeviceActivityReportBridge] Stopped report tracking")
        }
    }
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
}

