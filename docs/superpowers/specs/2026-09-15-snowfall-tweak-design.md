# Snowfall Tweak Design

## Goal
Build a free rootless iOS jailbreak tweak for Dopamine on an iPhone XS running iOS 18.6.2 that creates a Stella-like snow overlay, but with actual accumulation and slow melting.

## Platform
- Device target: iPhone XS / A12 / arm64e.
- OS target: iOS 18.6.2.
- Jailbreak: Dopamine rootless with ElleKit.
- Package manager: Sileo.
- Build host: Windows using WSL for local Theos work.
- Final arm64e build: macOS GitHub Actions runner using Xcode/Theos because modern arm64e system-binary builds require Apple's newer linker/toolchain.

## User Experience
- Snow appears on the Home Screen and Lock Screen.
- Snow renders above wallpaper, icons, dock, notifications, and lock-screen media controls where practical.
- Snow particles do not intercept touch input.
- Snowflakes fall with configurable density, speed, size, wind, and melt rate.
- Snow can land on supported UI surfaces instead of passing straight through them.
- Accumulated snow slowly melts so it cannot permanently bury the interface.
- A density slider controls snowfall from very light to heavy.

## Rendering Architecture
Use one transparent, non-interactive overlay view managed inside SpringBoard. The overlay owns the snow simulation and draws particles and accumulated snow. It must set user interaction off so taps and gestures continue to reach normal iOS UI.

The simulation uses a lightweight custom 2D particle model rather than SpriteKit. Each particle stores position, velocity, radius, lifetime/state, and melt progress. A display-link-driven update loop advances particles while the overlay is visible.

## Collision and Accumulation
Collision geometry is represented by simple rectangles derived from visible SpringBoard UI elements rather than pixel-perfect shape tests. Initial supported surfaces:
- Home Screen app icons.
- Dock bounds.
- Lock Screen notification cards.
- Lock Screen media controls when visible.
- Bottom screen boundary.

When a falling particle intersects a supported surface, it becomes accumulated snow. Accumulated snow is represented as small deposits associated with that surface. Deposits have a maximum depth and a melt timer. Old deposits shrink gradually and are removed when fully melted.

If a surface moves, disappears, or the user switches pages, its collision geometry is refreshed and stale deposits are discarded or remapped conservatively rather than remaining suspended in space.

## Performance Limits
- Target 60 FPS where practical, but simulation may reduce update frequency under load.
- Cap active falling particles based on the density slider.
- Cap accumulated deposits per surface.
- Pause or heavily reduce simulation while the display is off.
- Avoid continuous expensive view-tree scans; refresh collision surfaces on relevant SpringBoard layout/state changes and at a low fallback interval.

## Preferences
Expose settings through a rootless PreferenceLoader bundle with:
- Enabled toggle.
- Snowfall density slider.
- Fall speed slider.
- Particle size slider.
- Wind slider with left/right range.
- Melt rate slider.
- Reset Snow button that clears current accumulated deposits.

Settings changes should apply without requiring a full device reboot. A respring may be used only when a setting cannot be safely applied live.

## Packaging
- Rootless package scheme.
- Package architecture suitable for rootless iOS 15+ and arm64e SpringBoard injection.
- Inject only into SpringBoard.
- Use ElleKit for tweak injection.
- Produce a `.deb` installable through Sileo.

## Safety and Recovery
- Never modify system files permanently.
- Keep all tweak state ephemeral or in the tweak's preferences.
- If the tweak crashes SpringBoard, disabling tweak injection in Dopamine safe mode must allow recovery.
- Avoid private data access; the tweak only inspects UI geometry needed for rendering/collision.

## Testing
- Verify installation and removal through Sileo.
- Verify Home Screen snowfall and icon/dock accumulation.
- Verify Lock Screen snowfall and notification/media-control accumulation.
- Verify touch input remains normal beneath the overlay.
- Verify page swipes and icon rearrangement do not leave floating deposits.
- Verify density extremes do not cause unacceptable lag.
- Verify melt behavior clears old deposits.
- Verify disabling the tweak removes the overlay cleanly.
- Verify safe-mode recovery if SpringBoard crashes.
