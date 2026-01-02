#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(WidgetBridgeModule, NSObject)

RCT_EXTERN_METHOD(updateWidgetData:(double)walletBalance unlockSessionEndTime:(double)unlockSessionEndTime timeUntilReset:(double)timeUntilReset screenDailyAverageSeconds:(double)screenDailyAverageSeconds currentSteps:(double)currentSteps)

@end

