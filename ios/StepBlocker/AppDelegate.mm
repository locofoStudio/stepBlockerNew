#import "AppDelegate.h"

#import <React/RCTBundleURLProvider.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  NSLog(@"[AppDelegate] 🚀 Starting app initialization...");
  
  BOOL result = NO;
  @try {
    self.moduleName = @"StepBlocker";
    // You can add your custom initial props in the dictionary below.
    // They will be passed down to the ViewController used by React Native.
    self.initialProps = @{};

    NSLog(@"[AppDelegate] ✅ Module name set, calling super...");
    result = [super application:application didFinishLaunchingWithOptions:launchOptions];
    NSLog(@"[AppDelegate] ✅ Super initialization completed, result: %@", result ? @"YES" : @"NO");
  } @catch (NSException *exception) {
    NSLog(@"[AppDelegate] ❌ CRASH during initialization!");
    NSLog(@"[AppDelegate] Exception name: %@", exception.name);
    NSLog(@"[AppDelegate] Exception reason: %@", exception.reason);
    NSLog(@"[AppDelegate] Exception callStackSymbols: %@", exception.callStackSymbols);
    @throw; // Re-throw to see the crash in Xcode
  }
  
  // Debug: Log window and view hierarchy
  dispatch_async(dispatch_get_main_queue(), ^{
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (window) {
      NSLog(@"[AppDelegate] Window found: %@", window);
      NSLog(@"[AppDelegate] Window frame: %@", NSStringFromCGRect(window.frame));
      NSLog(@"[AppDelegate] Root VC: %@", window.rootViewController);
      if (window.rootViewController) {
        NSLog(@"[AppDelegate] Root VC view: %@", window.rootViewController.view);
        NSLog(@"[AppDelegate] Root VC view frame: %@", NSStringFromCGRect(window.rootViewController.view.frame));
        NSLog(@"[AppDelegate] Root VC view backgroundColor: %@", window.rootViewController.view.backgroundColor);
        NSLog(@"[AppDelegate] Root VC view subviews count: %lu", (unsigned long)window.rootViewController.view.subviews.count);
        
        // Check again after a delay to see if React Native has mounted
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          NSLog(@"[AppDelegate] After 2s delay - Root VC view subviews count: %lu", (unsigned long)window.rootViewController.view.subviews.count);
          if (window.rootViewController.view.subviews.count > 0) {
            for (UIView *subview in window.rootViewController.view.subviews) {
              NSLog(@"[AppDelegate] Subview: %@, frame: %@", subview, NSStringFromCGRect(subview.frame));
            }
          } else {
            NSLog(@"[AppDelegate] ⚠️ Still 0 subviews after 2s - React Native may not have mounted");
          }
        });
      }
    } else {
      NSLog(@"[AppDelegate] ❌ No key window found!");
    }
  });
  
  return result;
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
  return [self bundleURL];
}

- (NSURL *)bundleURL
{
  // Use Metro in Debug mode, bundled JS in Release mode
  // This is the standard React Native setup
#if DEBUG
  // Debug mode: Use Metro bundler (requires Metro to be running)
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index"];
#else
  // Release mode: Use bundled JS (no Metro required)
  NSURL *jsBundleURL = [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
  if (!jsBundleURL) {
    NSLog(@"Error: main.jsbundle not found in Release build!");
    // Fallback to Metro as last resort (shouldn't happen in Release)
    return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index"];
  }
  return jsBundleURL;
#endif
}

@end
