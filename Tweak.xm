#import <UIKit/UIKit.h>
#import "Sources/SFCoordinator.h"

static void SFRefreshSoon(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[SFCoordinator shared] refreshLayout];
    });
}

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[SFCoordinator shared] startIfNeeded];
    });
}

%end

%hook SBRootFolderView

- (void)layoutSubviews {
    %orig;
    SFRefreshSoon();
}

%end

%hook SBDockView

- (void)layoutSubviews {
    %orig;
    SFRefreshSoon();
}

%end

%hook CSCoverSheetView

- (void)layoutSubviews {
    %orig;
    SFRefreshSoon();
}

%end

%hook NCNotificationListView

- (void)layoutSubviews {
    %orig;
    SFRefreshSoon();
}

%end

%hook MRUNowPlayingView

- (void)layoutSubviews {
    %orig;
    SFRefreshSoon();
}

%end

%ctor {
    @autoreleasepool {
        [SFCoordinator shared];
    }
}
