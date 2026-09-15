#import "SFCoordinator.h"
#import "SFOverlayView.h"
#import "SFSurfaceProvider.h"
#import "SFSettings.h"
#import <UIKit/UIKit.h>
#include <memory>

static CFStringRef const SFClearSnowDarwin = CFSTR("com.vince.snowfall/clear");

@class SFCoordinator;
static void SFClearSnowDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

@interface SFCoordinator ()
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIViewController *overlayController;
@property (nonatomic, strong) SFOverlayView *overlayView;
@property (nonatomic, strong) SFSurfaceProvider *surfaceProvider;
@property (nonatomic, strong) NSTimer *fallbackTimer;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) BOOL suspended;
@end

@implementation SFCoordinator {
    std::unique_ptr<SFSimulation> _simulation;
}

+ (instancetype)shared {
    static SFCoordinator *coordinator;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coordinator = [SFCoordinator new];
    });
    return coordinator;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _simulation = std::make_unique<SFSimulation>((unsigned int)arc4random());
        _surfaceProvider = [SFSurfaceProvider new];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:) name:SFSettingsDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResign:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(protectedDataUnavailable:) name:UIApplicationProtectedDataWillBecomeUnavailable object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(protectedDataAvailable:) name:UIApplicationProtectedDataDidBecomeAvailable object:nil];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), SFClearSnowDarwinCallback, SFClearSnowDarwin, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}

- (UIWindowScene *)bestWindowScene {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *fallback = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (!fallback) {
                fallback = windowScene;
            }
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                return windowScene;
            }
        }
        return fallback;
    }
    return nil;
}

- (void)startIfNeeded {
    if (self.started) {
        return;
    }

    CGRect frame = UIScreen.mainScreen.bounds;
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = [self bestWindowScene];
        if (scene) {
            window = [[UIWindow alloc] initWithWindowScene:scene];
            window.frame = scene.coordinateSpace.bounds;
        }
    }
    if (!window) {
        window = [[UIWindow alloc] initWithFrame:frame];
    }

    UIViewController *controller = [UIViewController new];
    controller.view.backgroundColor = UIColor.clearColor;
    controller.view.userInteractionEnabled = NO;

    window.rootViewController = controller;
    window.backgroundColor = UIColor.clearColor;
    window.opaque = NO;
    window.userInteractionEnabled = NO;
    window.windowLevel = UIWindowLevelStatusBar - 1.0;

    SFOverlayView *overlay = [[SFOverlayView alloc] initWithFrame:controller.view.bounds simulation:_simulation.get()];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [controller.view addSubview:overlay];

    self.overlayWindow = window;
    self.overlayController = controller;
    self.overlayView = overlay;
    self.started = YES;

    [self applySettings];
    [overlay start];
    [self refreshLayout];

    self.fallbackTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(fallbackRefresh:) userInfo:nil repeats:YES];
}

- (void)settingsDidChange:(NSNotification *)notification {
    [self applySettings];
}

- (void)applicationWillResign:(NSNotification *)notification {
    self.suspended = YES;
    [self.overlayView stop];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    self.suspended = NO;
    [self.overlayView start];
    [self applySettings];
    [self refreshLayout];
}

- (void)protectedDataUnavailable:(NSNotification *)notification {
    self.suspended = YES;
    [self.overlayView stop];
}

- (void)protectedDataAvailable:(NSNotification *)notification {
    self.suspended = NO;
    [self.overlayView start];
    [self applySettings];
    [self refreshLayout];
}

- (void)applySettings {
    if (!self.started) {
        return;
    }
    SFSettingsSnapshot settings = [[SFSettings shared] snapshot];
    [self.overlayView applySettings:settings];
    self.overlayWindow.hidden = !settings.enabled;
    if (settings.enabled && !self.suspended) {
        self.overlayWindow.hidden = NO;
        [self.overlayView start];
    }
}

- (void)refreshLayout {
    if (!self.started || self.suspended) {
        return;
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performLayoutRefresh) object:nil];
    [self performSelector:@selector(performLayoutRefresh) withObject:nil afterDelay:0.08];
}

- (void)performLayoutRefresh {
    if (!self.overlayWindow || self.overlayWindow.hidden) {
        return;
    }
    [self.surfaceProvider invalidate];
    std::vector<SFSurface> surfaces = [self.surfaceProvider currentSurfacesForWindow:self.overlayWindow];
    [self.overlayView setCollisionSurfaces:surfaces];
}

- (void)fallbackRefresh:(NSTimer *)timer {
    if (!self.suspended) {
        [self refreshLayout];
    }
}

- (void)clearSnow {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.overlayView clearDeposits];
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), NULL, NULL);
    [self.fallbackTimer invalidate];
}

@end

static void SFClearSnowDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    SFCoordinator *coordinator = (__bridge SFCoordinator *)observer;
    [coordinator clearSnow];
}
