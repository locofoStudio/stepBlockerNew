#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(BlockerModule, NSObject)

RCT_EXTERN_METHOD(setBlockedApps:(NSArray *)bundleIds)
RCT_EXTERN_METHOD(toggleBlocking:(BOOL)enabled)
RCT_EXTERN_METHOD(requestAuthorization:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(presentAppPicker:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(setRemainingTime:(int)minutes)
RCT_EXTERN_METHOD(unlockApps:(NSNumber *)minutes resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(endSessionEarly:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(getWalletBalance:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(addToWalletBalance:(NSNumber *)minutes resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(resetWalletBalance:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)

@end
