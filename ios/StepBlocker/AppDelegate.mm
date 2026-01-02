#import "AppDelegate.h"

#import <React/RCTBundleURLProvider.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.moduleName = @"StepBlocker";
  // You can add your custom initial props in the dictionary below.
  // They will be passed down to the ViewController used by React Native.
  self.initialProps = @{};

  return [super application:application didFinishLaunchingWithOptions:launchOptions];
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
