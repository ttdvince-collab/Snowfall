#import "SFSurfaceProvider.h"
#import <QuartzCore/QuartzCore.h>
#include <cmath>
#include <cstdint>
#include <string>
#include <unordered_set>

static uint32_t SFFNV1a(const std::string& value) {
    uint32_t hash = 2166136261u;
    for (unsigned char byte : value) {
        hash ^= byte;
        hash *= 16777619u;
    }
    return hash;
}

static bool SFContainsToken(NSString *name, NSString *token) {
    return [name rangeOfString:token options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static bool SFIsCandidateView(UIView *view, CGRect rect, CGSize screenSize) {
    NSString *name = NSStringFromClass(view.class);
    CGFloat width = CGRectGetWidth(rect);
    CGFloat height = CGRectGetHeight(rect);

    if (SFContainsToken(name, @"IconView")) {
        return width >= 20.0 && width <= 140.0 && height >= 20.0 && height <= 160.0;
    }

    if (SFContainsToken(name, @"Dock")) {
        return width >= 80.0 && height >= 20.0 && height <= 180.0;
    }

    if (SFContainsToken(name, @"Notification")) {
        return width >= 80.0 && width <= screenSize.width + 20.0 && height >= 20.0 && height <= 320.0;
    }

    if (SFContainsToken(name, @"MediaControls") || SFContainsToken(name, @"NowPlaying")) {
        return width >= 60.0 && height >= 30.0 && height <= 360.0;
    }

    return false;
}

static int SFStableSurfaceId(UIView *view, CGRect rect) {
    NSString *className = NSStringFromClass(view.class);
    int x = (int)lrint(CGRectGetMinX(rect) * 2.0);
    int y = (int)lrint(CGRectGetMinY(rect) * 2.0);
    int w = (int)lrint(CGRectGetWidth(rect) * 2.0);
    int h = (int)lrint(CGRectGetHeight(rect) * 2.0);
    NSString *value = [NSString stringWithFormat:@"%@:%d:%d:%d:%d", className, x, y, w, h];
    uint32_t hash = SFFNV1a(value.UTF8String ? value.UTF8String : "surface");
    return (int)(hash & 0x7fffffff);
}

static CGRect SFRectInTargetWindow(UIView *view, UIWindow *targetWindow) {
    if (!view.window || !targetWindow) {
        return CGRectNull;
    }

    CGRect inSourceWindow = [view convertRect:view.bounds toView:view.window];
    CGRect inScreen = [view.window convertRect:inSourceWindow toWindow:nil];
    return [targetWindow convertRect:inScreen fromWindow:nil];
}

static void SFScanView(
    UIView *view,
    UIWindow *targetWindow,
    CGRect screenBounds,
    std::unordered_set<int>& seen,
    std::vector<SFSurface>& output
) {
    if (view.hidden || view.alpha < 0.05 || CGRectIsEmpty(view.bounds)) {
        return;
    }

    CGRect rect = SFRectInTargetWindow(view, targetWindow);

    if (
        !CGRectIsNull(rect) &&
        !CGRectIsEmpty(rect) &&
        CGRectIntersectsRect(rect, screenBounds) &&
        SFIsCandidateView(view, rect, screenBounds.size)
    ) {
        NSString *name = NSStringFromClass(view.class);

        if (SFContainsToken(name, @"IconView")) {
            rect.size.height *= 0.85;
        }

        rect = CGRectIntersection(rect, screenBounds);

        if (!CGRectIsEmpty(rect)) {
            int surfaceId = SFStableSurfaceId(view, rect);

            if (seen.insert(surfaceId).second) {
                output.push_back(SFSurface{
                    surfaceId,
                    SFRect{
                        (float)CGRectGetMinX(rect),
                        (float)CGRectGetMinY(rect),
                        (float)CGRectGetWidth(rect),
                        (float)CGRectGetHeight(rect)
                    }
                });
            }
        }
    }

    for (UIView *subview in view.subviews) {
        SFScanView(subview, targetWindow, screenBounds, seen, output);
    }
}

@interface SFSurfaceProvider ()
@property (nonatomic, assign) BOOL invalidated;
@property (nonatomic, assign) CFTimeInterval lastRefresh;
@end

@implementation SFSurfaceProvider {
    std::vector<SFSurface> _cached;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        _invalidated = YES;
    }

    return self;
}

- (void)invalidate {
    self.invalidated = YES;
}

- (std::vector<SFSurface>)currentSurfacesForWindow:(UIWindow *)window {
    if (!window) {
        return {};
    }

    CFTimeInterval now = CACurrentMediaTime();

    if (!self.invalidated && now - self.lastRefresh < 2.0) {
        return _cached;
    }

    std::vector<SFSurface> surfaces;
    std::unordered_set<int> seen;
    CGRect screenBounds = window.bounds;
    UIApplication *application = UIApplication.sharedApplication;

    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];

    for (UIScene *scene in application.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        [windows addObjectsFromArray:windowScene.windows];
    }

    for (UIWindow *candidateWindow in windows) {
        if (candidateWindow.hidden || candidateWindow.alpha < 0.05) {
            continue;
        }

        SFScanView(candidateWindow, window, screenBounds, seen, surfaces);
    }

    int bottomId = 2147483000;

    surfaces.push_back(SFSurface{
        bottomId,
        SFRect{
            0.0f,
            (float)MAX(0.0, CGRectGetHeight(screenBounds) - 2.0),
            (float)CGRectGetWidth(screenBounds),
            2.0f
        }
    });

    _cached = surfaces;
    self.invalidated = NO;
    self.lastRefresh = now;

    return _cached;
}

@end
