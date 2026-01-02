#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(DeviceActivityReportBridge, NSObject)

RCT_EXTERN_METHOD(startReportTracking)
RCT_EXTERN_METHOD(stopReportTracking)

@end

