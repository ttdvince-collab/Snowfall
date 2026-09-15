#import "SnowfallPrefsRootListController.h"

@implementation SnowfallPrefsRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)resetSnow {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.vince.snowfall/clear"), NULL, NULL, YES);
}

@end
