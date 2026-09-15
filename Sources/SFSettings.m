#import "SFSettings.h"

NSString * const SFSettingsDidChangeNotification = @"com.vince.snowfall/settings.changed";
NSString * const SFClearSnowNotification = @"com.vince.snowfall/clear";

static NSString * const SFPreferencesDomain = @"com.vince.snowfall";
static CFStringRef const SFPreferencesChangedDarwin = CFSTR("com.vince.snowfall/preferences.changed");

static void SFSettingsDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

static id SFPreferenceValue(NSString *key) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)SFPreferencesDomain);
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)SFPreferencesDomain);
    return CFBridgingRelease(value);
}

static CGFloat SFFloatValue(NSString *key, CGFloat fallback) {
    id value = SFPreferenceValue(key);
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : fallback;
}

static BOOL SFBoolValue(NSString *key, BOOL fallback) {
    id value = SFPreferenceValue(key);
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : fallback;
}

static void SFSettingsDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    SFSettings *settings = (__bridge SFSettings *)observer;
    dispatch_async(dispatch_get_main_queue(), ^{
        [settings reload];
        [[NSNotificationCenter defaultCenter] postNotificationName:SFSettingsDidChangeNotification object:settings];
    });
}


@interface SFSettings ()
@property (nonatomic, assign) SFSettingsSnapshot current;
@end

@implementation SFSettings

+ (instancetype)shared {
    static SFSettings *settings;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        settings = [SFSettings new];
        [settings reload];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(settings), SFSettingsDarwinCallback, SFPreferencesChangedDarwin, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    });
    return settings;
}

- (void)reload {
    SFSettingsSnapshot snapshot;
    snapshot.enabled = SFBoolValue(@"enabled", YES);
    snapshot.density = SFFloatValue(@"density", 0.45);
    snapshot.fallSpeed = SFFloatValue(@"fallSpeed", 1.0);
    snapshot.particleSize = SFFloatValue(@"particleSize", 1.0);
    snapshot.wind = SFFloatValue(@"wind", 0.0);
    snapshot.meltRate = SFFloatValue(@"meltRate", 0.12);
    self.current = snapshot;
}

- (SFSettingsSnapshot)snapshot {
    return self.current;
}

@end
