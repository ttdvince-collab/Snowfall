#import <UIKit/UIKit.h>
#import "SFSettings.h"

#ifdef __cplusplus
#include <vector>
#include "SFSimulation.hpp"
#endif

@interface SFOverlayView : UIView
#ifdef __cplusplus
- (instancetype)initWithFrame:(CGRect)frame simulation:(SFSimulation *)simulation;
- (void)setCollisionSurfaces:(const std::vector<SFSurface>&)surfaces;
#endif
- (void)start;
- (void)stop;
- (void)applySettings:(SFSettingsSnapshot)settings;
- (void)clearDeposits;
@end
