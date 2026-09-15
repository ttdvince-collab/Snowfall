#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef struct {
    BOOL enabled;
    CGFloat density;
    CGFloat fallSpeed;
    CGFloat particleSize;
    CGFloat wind;
    CGFloat meltRate;
} SFSettingsSnapshot;

FOUNDATION_EXPORT NSString * const SFSettingsDidChangeNotification;
FOUNDATION_EXPORT NSString * const SFClearSnowNotification;

@interface SFSettings : NSObject
+ (instancetype)shared;
- (SFSettingsSnapshot)snapshot;
- (void)reload;
@end
