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
