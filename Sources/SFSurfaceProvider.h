#import <UIKit/UIKit.h>

#ifdef __cplusplus
#include <vector>
#include "SFSimulation.hpp"
#endif

@interface SFSurfaceProvider : NSObject
#ifdef __cplusplus
- (std::vector<SFSurface>)currentSurfacesForWindow:(UIWindow *)window;
#endif
- (void)invalidate;
@end
