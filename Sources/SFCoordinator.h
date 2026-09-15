#import <Foundation/Foundation.h>

@interface SFCoordinator : NSObject
+ (instancetype)shared;
- (void)startIfNeeded;
- (void)refreshLayout;
- (void)applySettings;
- (void)clearSnow;
@end
