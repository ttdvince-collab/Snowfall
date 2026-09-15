# Snowfall Tweak Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a free rootless Dopamine tweak for iPhone XS on iOS 18.6.2 that renders Stella-style falling snow, lets snow accumulate on SpringBoard UI surfaces, and slowly melts deposits.

**Architecture:** Keep the simulation core independent of UIKit so particle motion, collision, accumulation, and melting can be tested on the build host. Inject one transparent non-interactive overlay into SpringBoard, feed it lightweight collision rectangles from visible Home Screen and Lock Screen views, and draw falling particles plus deposits with Core Animation/UIKit. Use a rootless PreferenceLoader bundle for controls and a macOS GitHub Actions job for final arm64e packaging.

**Tech Stack:** Theos, Logos/Objective-C++, UIKit/Core Animation, ElleKit, PreferenceLoader, pure C++17 simulation core, shell/Make, GitHub Actions macOS runner.

**Spec:** `docs/superpowers/specs/2026-09-15-snowfall-tweak-design.md`

## Global Constraints

- Device target: iPhone XS / A12 / arm64e.
- OS target: iOS 18.6.2.
- Jailbreak: Dopamine rootless with ElleKit.
- Package manager: Sileo.
- Build host: Windows using WSL for local Theos work.
- Final arm64e build: macOS GitHub Actions runner using Xcode/Theos.
- Rootless package scheme only.
- Inject only into SpringBoard.
- Never modify system files permanently.
- Overlay must never intercept touch input.
- Snow density, speed, size, wind, and melt rate must be adjustable.
- Disabling the tweak must remove its overlay cleanly.

---

## File Map

- `Makefile` — top-level Theos targets and subprojects.
- `control` — Debian package metadata.
- `Snowfall.plist` — SpringBoard-only injection filter.
- `Tweak.xm` — SpringBoard lifecycle/layout hooks and coordinator startup.
- `Sources/SFTypes.hpp` — plain geometry and simulation value types.
- `Sources/SFSimulation.hpp` / `Sources/SFSimulation.cpp` — falling-particle and deposit simulation.
- `Sources/SFSettings.h` / `Sources/SFSettings.m` — preference loading and change notifications.
- `Sources/SFSurfaceProvider.h` / `Sources/SFSurfaceProvider.mm` — converts visible SpringBoard views into collision rectangles.
- `Sources/SFOverlayView.h` / `Sources/SFOverlayView.mm` — transparent rendering surface and display-link loop.
- `Sources/SFCoordinator.h` / `Sources/SFCoordinator.mm` — owns settings, surface provider, simulation, and overlay lifecycle.
- `prefs/Makefile` — PreferenceLoader bundle build.
- `prefs/SnowfallPrefsRootListController.h` / `.m` — preferences controller and reset action.
- `prefs/Resources/Root.plist` — sliders/toggles.
- `prefs/Resources/Info.plist` — bundle metadata.
- `tests/simulation_tests.cpp` — host-side deterministic simulation tests.
- `scripts/test-simulation.sh` — compile/run pure C++ tests on WSL/macOS.
- `.github/workflows/build.yml` — macOS arm64e `.deb` build artifact.

---

### Task 1: Scaffold the rootless Theos package and host-side test harness

**Files:**
- Create: `Makefile`
- Create: `control`
- Create: `Snowfall.plist`
- Create: `Tweak.xm`
- Create: `Sources/SFTypes.hpp`
- Create: `tests/simulation_tests.cpp`
- Create: `scripts/test-simulation.sh`
- Create: `prefs/Makefile`
- Create: `prefs/Resources/Info.plist`

**Interfaces:**
- Consumes: Theos rootless toolchain and C++17 compiler.
- Produces: buildable package skeleton plus `./scripts/test-simulation.sh` as the repeatable host-side test command.

- [ ] **Step 1: Write the first failing host-side test**

Create `tests/simulation_tests.cpp` with a compile-time dependency on `SFVec2` and `SFRect` that do not exist yet:

```cpp
#include <cassert>
#include "../Sources/SFTypes.hpp"

int main() {
    SFVec2 p{10.0f, 20.0f};
    SFRect r{0.0f, 0.0f, 30.0f, 40.0f};
    assert(r.contains(p));
    return 0;
}
```

- [ ] **Step 2: Add the host test runner and verify failure**

Create `scripts/test-simulation.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
mkdir -p .build-tests
c++ -std=c++17 -Wall -Wextra -Werror tests/simulation_tests.cpp Sources/SFSimulation.cpp -o .build-tests/simulation_tests
.build-tests/simulation_tests
```

Run:

```bash
chmod +x scripts/test-simulation.sh
./scripts/test-simulation.sh
```

Expected: FAIL because `Sources/SFTypes.hpp` and `Sources/SFSimulation.cpp` do not exist yet.

- [ ] **Step 3: Add minimal geometry types**

Create `Sources/SFTypes.hpp`:

```cpp
#pragma once

struct SFVec2 {
    float x;
    float y;
};

struct SFRect {
    float x;
    float y;
    float width;
    float height;

    bool contains(const SFVec2& p) const {
        return p.x >= x && p.x <= x + width && p.y >= y && p.y <= y + height;
    }
};
```

Create an empty `Sources/SFSimulation.cpp` so the test command links.

- [ ] **Step 4: Add Theos package metadata**

Create `control`:

```text
Package: com.vince.snowfall
Name: Snowfall
Version: 0.1.0
Architecture: iphoneos-arm64
Description: Interactive accumulating snow for SpringBoard.
Maintainer: Vince
Author: Vince
Section: Tweaks
Depends: mobilesubstrate, preferenceloader
```

Create `Snowfall.plist`:

```plist
{
    Filter = {
        Bundles = ("com.apple.springboard");
    };
}
```

Create top-level `Makefile`:

```make
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Snowfall
Snowfall_FILES = Tweak.xm Sources/SFSettings.m Sources/SFSurfaceProvider.mm Sources/SFOverlayView.mm Sources/SFCoordinator.mm Sources/SFSimulation.cpp
Snowfall_CFLAGS = -fobjc-arc
Snowfall_CCFLAGS = -std=c++17
Snowfall_FRAMEWORKS = UIKit QuartzCore CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
```

Create a minimal `Tweak.xm` with only the imports and `%ctor {}` so packaging can be wired before behavior exists.

- [ ] **Step 5: Add PreferenceLoader subproject metadata**

Create `prefs/Makefile`:

```make
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SnowfallPrefs
SnowfallPrefs_FILES = SnowfallPrefsRootListController.m
SnowfallPrefs_FRAMEWORKS = UIKit
SnowfallPrefs_PRIVATE_FRAMEWORKS = Preferences
SnowfallPrefs_INSTALL_PATH = /Library/PreferenceBundles
SnowfallPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
```

Create `prefs/Resources/Info.plist` with bundle identifier `com.vince.snowfallprefs` and principal class `SnowfallPrefsRootListController`.

- [ ] **Step 6: Run the host test**

Run:

```bash
./scripts/test-simulation.sh
```

Expected: PASS.

- [ ] **Step 7: Verify Theos parses the project**

Run in WSL:

```bash
make clean
```

Expected: no Makefile syntax or missing-subproject error.

- [ ] **Step 8: Commit**

```bash
git add Makefile control Snowfall.plist Tweak.xm Sources tests scripts prefs
git commit -m "chore: scaffold rootless snowfall tweak"
```

---

### Task 2: Build the deterministic snow simulation core

**Files:**
- Create: `Sources/SFSimulation.hpp`
- Modify: `Sources/SFSimulation.cpp`
- Modify: `tests/simulation_tests.cpp`

**Interfaces:**
- Consumes: `SFVec2`, `SFRect` from `SFTypes.hpp`.
- Produces: `SFSimulation`, `SFParticle`, `SFDeposit`, `SFSimulationConfig`.

Define these interfaces exactly:

```cpp
struct SFParticle {
    SFVec2 position;
    SFVec2 velocity;
    float radius;
    bool active;
};

struct SFDeposit {
    int surfaceId;
    SFVec2 position;
    float radius;
    float remaining;
};

struct SFSurface {
    int id;
    SFRect rect;
};

struct SFSimulationConfig {
    float width;
    float height;
    float density;
    float fallSpeed;
    float particleSize;
    float wind;
    float meltRate;
    int maxParticles;
    int maxDepositsPerSurface;
};

class SFSimulation {
public:
    explicit SFSimulation(unsigned int seed);
    void setConfig(const SFSimulationConfig& config);
    void setSurfaces(const std::vector<SFSurface>& surfaces);
    void update(float dt);
    void clearDeposits();
    const std::vector<SFParticle>& particles() const;
    const std::vector<SFDeposit>& deposits() const;
};
```

- [ ] **Step 1: Add failing tests for falling motion and wind**

Extend `tests/simulation_tests.cpp` to create a simulation with deterministic seed, one particle, update by `0.5f`, and assert that Y increases and X changes in the wind direction.

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
./scripts/test-simulation.sh
```

Expected: FAIL because `SFSimulation` does not exist.

- [ ] **Step 3: Implement minimal particle spawning and integration**

Implement config storage, deterministic RNG, density-driven spawning, vertical velocity based on `fallSpeed`, horizontal drift based on `wind`, and removal/recycling when a particle leaves the bottom or horizontal bounds.

- [ ] **Step 4: Add failing collision-to-deposit test**

Add a surface rectangle around Y=100. Spawn a particle just above it, update until intersection, then assert falling particle count decreases and a deposit exists with the matching `surfaceId`.

- [ ] **Step 5: Implement rectangle collision and deposit creation**

Collision rule: a particle lands when its center moves downward across a surface's top edge and its X falls within `[rect.x - radius, rect.x + rect.width + radius]`. Place the deposit at `y = rect.y - radius`.

- [ ] **Step 6: Add failing melt test**

Create a deposit with finite `remaining`, advance time, and assert deposit size/lifetime decreases and eventually disappears.

- [ ] **Step 7: Implement gradual melting**

Decrease `remaining` by `meltRate * dt`; render radius later as `baseRadius * clamp(remaining, 0, 1)`. Remove deposits at `remaining <= 0`.

- [ ] **Step 8: Add failing cap tests**

Verify active particles never exceed `maxParticles` and each surface never exceeds `maxDepositsPerSurface` even under heavy density.

- [ ] **Step 9: Implement caps**

Skip spawning at the active-particle cap. When a surface reaches its deposit cap, merge new impact mass into the nearest deposit instead of adding a new entry.

- [ ] **Step 10: Run all simulation tests**

Run:

```bash
./scripts/test-simulation.sh
```

Expected: PASS with zero warnings.

- [ ] **Step 11: Commit**

```bash
git add Sources/SFSimulation.hpp Sources/SFSimulation.cpp tests/simulation_tests.cpp
git commit -m "feat: add deterministic snow simulation"
```

---

### Task 3: Add live preference loading and reset notification

**Files:**
- Create: `Sources/SFSettings.h`
- Create: `Sources/SFSettings.m`
- Create: `prefs/SnowfallPrefsRootListController.h`
- Create: `prefs/SnowfallPrefsRootListController.m`
- Create: `prefs/Resources/Root.plist`

**Interfaces:**
- Produces: `SFSettingsSnapshot`, `SFSettingsDidChangeNotification`, `SFClearSnowNotification`.

Use this Objective-C interface:

```objc
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
```

Preferences domain: `com.vince.snowfall`.

Defaults:

```text
enabled = YES
density = 0.45
fallSpeed = 1.0
particleSize = 1.0
wind = 0.0
meltRate = 0.12
```

- [ ] **Step 1: Create the preference plist**

`prefs/Resources/Root.plist` must contain:

```text
Enabled toggle
Density slider: 0.0 ... 1.0
Fall Speed slider: 0.25 ... 2.0
Particle Size slider: 0.5 ... 2.0
Wind slider: -1.0 ... 1.0
Melt Rate slider: 0.02 ... 0.5
Reset Snow button
```

All controls save under `defaults = com.vince.snowfall`.

- [ ] **Step 2: Implement settings loading**

Read values through `NSUserDefaults`/CFPreferences for the tweak domain and expose a snapshot. Register for Darwin notification `com.vince.snowfall/preferences.changed` and post `SFSettingsDidChangeNotification` inside SpringBoard after reload.

- [ ] **Step 3: Implement Reset Snow**

`SnowfallPrefsRootListController` posts Darwin notification `com.vince.snowfall/clear` when the Reset Snow button is tapped.

- [ ] **Step 4: Wire preference changes to Darwin notification**

Set each plist specifier's `PostNotification` to `com.vince.snowfall/preferences.changed`.

- [ ] **Step 5: Build the preference bundle locally**

Run:

```bash
make clean package
```

Expected: package stage succeeds on any host with a working Theos toolchain; if WSL cannot link arm64e, compilation may stop at the linker but plist/bundle generation must be valid.

- [ ] **Step 6: Commit**

```bash
git add Sources/SFSettings.h Sources/SFSettings.m prefs
git commit -m "feat: add snowfall preferences"
```

---

### Task 4: Render particles and deposits in a non-interactive overlay

**Files:**
- Create: `Sources/SFOverlayView.h`
- Create: `Sources/SFOverlayView.mm`
- Modify: `Sources/SFSimulation.hpp`

**Interfaces:**
- Consumes: `SFSimulation`, `SFSettingsSnapshot`, `[SFSurface]` geometry.
- Produces: `SFOverlayView` with live start/stop/update behavior.

Use this interface:

```objc
@interface SFOverlayView : UIView
- (instancetype)initWithFrame:(CGRect)frame simulation:(SFSimulation *)simulation;
- (void)start;
- (void)stop;
- (void)applySettings:(SFSettingsSnapshot)settings;
- (void)setCollisionSurfaces:(const std::vector<SFSurface>&)surfaces;
- (void)clearDeposits;
@end
```

- [ ] **Step 1: Implement transparent pass-through view behavior**

Set:

```text
backgroundColor = clearColor
userInteractionEnabled = NO
opaque = NO
clipsToBounds = YES
```

Override `pointInside:withEvent:` to return `NO` as an extra guarantee.

- [ ] **Step 2: Add the display-link update loop**

Use `CADisplayLink`. Clamp frame delta to `1/15` seconds to prevent giant simulation jumps after stalls. Pause the link when `window == nil` or the tweak is disabled.

- [ ] **Step 3: Draw falling particles**

In `drawRect:`, render each active particle as a soft white circle. Use Core Graphics fill with alpha between `0.65` and `0.95`. Do not allocate a UIView/CALayer per particle.

- [ ] **Step 4: Draw accumulated deposits**

Render deposits as overlapping white circles/short rounded blobs at the surface top. Scale each deposit visually using its remaining melt fraction.

- [ ] **Step 5: Map sliders into simulation limits**

Use these mappings:

```text
density 0...1 -> maxParticles 20...220
fallSpeed -> 35...180 points/sec multiplier
particleSize -> radius 1.5...6.0 points
wind -1...1 -> -60...60 points/sec
meltRate -> deposit lifetime approximately 5...80 seconds
maxDepositsPerSurface = 48
```

- [ ] **Step 6: Add load shedding**

If average display-link interval exceeds `1/40` seconds for 30 frames, temporarily reduce the spawn cap by 25%. Restore gradually when frame pacing recovers.

- [ ] **Step 7: Build**

Run:

```bash
make clean package
```

Expected: no Objective-C++ type errors.

- [ ] **Step 8: Commit**

```bash
git add Sources/SFOverlayView.h Sources/SFOverlayView.mm Sources/SFSimulation.hpp Sources/SFSimulation.cpp
git commit -m "feat: render falling and accumulated snow"
```

---

### Task 5: Discover Home Screen and Lock Screen collision surfaces

**Files:**
- Create: `Sources/SFSurfaceProvider.h`
- Create: `Sources/SFSurfaceProvider.mm`

**Interfaces:**
- Produces: stable `std::vector<SFSurface>` in overlay-window coordinates.

Use this interface:

```objc
@interface SFSurfaceProvider : NSObject
- (std::vector<SFSurface>)currentSurfacesForWindow:(UIWindow *)window;
- (void)invalidate;
@end
```

- [ ] **Step 1: Implement safe recursive view discovery**

Walk the visible SpringBoard view tree from the overlay host window's sibling/root views. Only inspect class names and geometry; do not read user data or labels.

Match candidate classes by conservative substrings:

```text
Icon
Dock
Notification
MediaControls
NowPlaying
```

Ignore hidden views, alpha below `0.05`, zero-sized frames, and frames that do not intersect the screen.

- [ ] **Step 2: Convert candidates to rectangles**

Convert each candidate's bounds to the overlay window with `convertRect:toView:`. For icons, use only the upper ~85% of the icon frame so accumulated snow visually sits on the icon rather than its label.

- [ ] **Step 3: Add the bottom screen surface**

Always append a full-width surface at the bottom of the display with a 2-point-high rectangle.

- [ ] **Step 4: Assign stable IDs per refresh**

Hash candidate class name plus rounded X/Y/width/height into a deterministic 31-bit positive `surfaceId`. The same unmoved surface should keep the same ID across refreshes.

- [ ] **Step 5: Limit scanning cost**

Cache results. Recompute only after `invalidate`, orientation/size change, page/layout notifications, or a 2-second fallback interval.

- [ ] **Step 6: Build**

Run:

```bash
make clean package
```

Expected: successful Objective-C++ compilation.

- [ ] **Step 7: Commit**

```bash
git add Sources/SFSurfaceProvider.h Sources/SFSurfaceProvider.mm
git commit -m "feat: detect springboard snow collision surfaces"
```

---

### Task 6: Coordinate overlay lifecycle inside SpringBoard

**Files:**
- Create: `Sources/SFCoordinator.h`
- Create: `Sources/SFCoordinator.mm`
- Modify: `Tweak.xm`

**Interfaces:**
- Consumes: `SFSettings`, `SFSurfaceProvider`, `SFOverlayView`.
- Produces: one process-wide `SFCoordinator` and no duplicate overlays.

Use this interface:

```objc
@interface SFCoordinator : NSObject
+ (instancetype)shared;
- (void)startIfNeeded;
- (void)refreshLayout;
- (void)applySettings;
- (void)clearSnow;
@end
```

- [ ] **Step 1: Create exactly one overlay window/view host**

Attach the overlay to SpringBoard after application launch. Prefer adding the overlay view to a stable SpringBoard root window above wallpaper and main content while keeping it non-interactive. If a dedicated overlay `UIWindow` is required for reliable z-order, set `userInteractionEnabled = NO` and a window level that stays below system alerts/keyboards.

- [ ] **Step 2: Wire settings notifications**

Observe `SFSettingsDidChangeNotification`; enable/disable the overlay live and update simulation parameters without respring.

- [ ] **Step 3: Wire clear notification**

Listen to Darwin notification `com.vince.snowfall/clear` and call `clearSnow`.

- [ ] **Step 4: Hook SpringBoard lifecycle**

In `Tweak.xm`, hook a stable application-finished-launching point and call `[[SFCoordinator shared] startIfNeeded]` on the main queue.

- [ ] **Step 5: Hook layout-changing events conservatively**

Trigger `refreshLayout` after Home Screen page transitions, icon editing/rearrangement layout passes, lock/unlock state changes, and notification list layout changes when hook targets are present. Keep each hook limited to calling `%orig` then scheduling a debounced refresh; do not duplicate SpringBoard behavior.

- [ ] **Step 6: Add fallback refresh timer**

Coordinator requests a surface refresh at most once every 2 seconds while the display is active, covering OS class-name/layout differences when a specific hook misses.

- [ ] **Step 7: Handle screen-off state**

Pause the overlay/display link when protected data becomes unavailable or SpringBoard enters display-off state; resume after wake.

- [ ] **Step 8: Build**

Run:

```bash
make clean package
```

Expected: package compiles with no duplicate-symbol or ARC ownership errors.

- [ ] **Step 9: Commit**

```bash
git add Tweak.xm Sources/SFCoordinator.h Sources/SFCoordinator.mm
git commit -m "feat: integrate snowfall with springboard"
```

---

### Task 7: Package for rootless Dopamine and build arm64e on GitHub Actions

**Files:**
- Modify: `control`
- Modify: `Makefile`
- Create: `.github/workflows/build.yml`
- Create: `README.md`

**Interfaces:**
- Produces: downloadable rootless `.deb` artifact from GitHub Actions.

- [ ] **Step 1: Confirm rootless package paths**

Run:

```bash
make package FINALPACKAGE=1
```

Inspect staged package contents and verify tweak dylib/plist and PreferenceLoader bundle resolve under Theos rootless packaging paths rather than hard-coded `/Library` locations in compiled install rules.

- [ ] **Step 2: Create the macOS workflow**

Create `.github/workflows/build.yml` that:

```text
checks out the repository
installs Theos into $HOME/theos
sets THEOS=$HOME/theos
installs ldid if required by the runner
runs scripts/test-simulation.sh
runs make clean package FINALPACKAGE=1
uploads packages/*.deb as artifact Snowfall-rootless
```

Use a current macOS runner and Xcode selected by the runner image; do not pin a deprecated Xcode path.

- [ ] **Step 3: Document build/install workflow**

`README.md` must include:

```text
1. push repository to GitHub
2. open Actions -> Build Snowfall
3. download Snowfall-rootless artifact
4. move .deb to iPhone using Files/AirDrop/SSH-compatible transfer
5. open/install .deb through Sileo or a package installer
6. respring
7. settings -> Snowfall
```

- [ ] **Step 4: Run host tests locally**

Run:

```bash
./scripts/test-simulation.sh
```

Expected: PASS.

- [ ] **Step 5: Push and verify CI**

Push the branch and run the workflow.

Expected: workflow passes and publishes one `.deb` artifact.

- [ ] **Step 6: Commit**

```bash
git add Makefile control .github/workflows/build.yml README.md
git commit -m "ci: build rootless arm64e package"
```

---

### Task 8: Device verification on iPhone XS / iOS 18.6.2

**Files:**
- Modify only if defects are found in earlier files.
- Create: `docs/device-test-results.md`

**Interfaces:**
- Consumes: CI-built `.deb`.
- Produces: verified installable tweak and a recorded device test matrix.

- [ ] **Step 1: Install through Sileo**

Install the `.deb`, respring, and confirm SpringBoard returns normally.

Expected: no safe mode and a `Snowfall` settings pane appears.

- [ ] **Step 2: Verify touch pass-through**

Open apps, long-press icons, swipe Home Screen pages, open Control Center, and interact with notifications while snow is visible.

Expected: snow never captures touch.

- [ ] **Step 3: Verify Home Screen accumulation**

Set density near 70%, wait 30 seconds, and observe icons, dock, and bottom edge.

Expected: deposits form on surfaces and do not float after a page swipe.

- [ ] **Step 4: Verify Lock Screen accumulation**

Lock the phone, create/show a notification and media controls, then wait.

Expected: snow falls over the Lock Screen and deposits on detected notification/media surfaces where the OS exposes stable views.

- [ ] **Step 5: Verify melting**

Set melt rate high, stop generating heavy snow by lowering density, and observe existing deposits.

Expected: deposits shrink and disappear gradually.

- [ ] **Step 6: Verify settings live-update**

Change density, speed, size, wind, and melt rate.

Expected: each change is visible within about one second without a device reboot.

- [ ] **Step 7: Verify Reset Snow**

Accumulate snow, tap `Reset Snow` in preferences.

Expected: all deposits clear immediately while falling snow continues.

- [ ] **Step 8: Verify performance extremes**

Set density to maximum for 60 seconds.

Expected: SpringBoard stays responsive; adaptive spawn cap lowers load if frame pacing degrades.

- [ ] **Step 9: Verify disable/removal**

Turn the tweak off in settings, then uninstall it through Sileo.

Expected: overlay disappears and no visual artifact remains after respring.

- [ ] **Step 10: Verify recovery**

If any device test causes SpringBoard to loop, reboot into Dopamine without tweak injection, remove/disable Snowfall, then re-enable injection.

Expected: the device remains recoverable without restoring iOS.

- [ ] **Step 11: Record results**

Create `docs/device-test-results.md` with device, iOS, package version, pass/fail for every test above, and any OS-specific class names that needed adjustment.

- [ ] **Step 12: Final verification**

Run:

```bash
./scripts/test-simulation.sh
```

Then trigger one clean GitHub Actions build.

Expected: host tests PASS, CI PASS, `.deb` installs on the iPhone XS, and all device checks pass or have explicitly documented limitations.

- [ ] **Step 13: Commit**

```bash
git add docs/device-test-results.md
git commit -m "test: verify snowfall on iphone xs ios 18"
```

---

## Self-Review

- Spec coverage: Home Screen/Lock Screen overlay, icon/dock/notification/media collisions, bottom boundary, density/speed/size/wind/melt controls, reset, touch pass-through, melting, load caps, screen-off pause, rootless packaging, Sileo installation, safe-mode recovery, and device verification are all mapped to tasks.
- Placeholder scan: no TBD/TODO/"implement later" steps remain.
- Type consistency: `SFSimulation`, `SFSurface`, `SFSettingsSnapshot`, `SFSurfaceProvider`, `SFOverlayView`, and `SFCoordinator` names/signatures are consistent across tasks.
