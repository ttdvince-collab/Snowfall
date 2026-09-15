#import "SFOverlayView.h"
#import <QuartzCore/QuartzCore.h>
#include <algorithm>
#include <cmath>

static CGFloat SFClamp(CGFloat value, CGFloat minimum, CGFloat maximum) {
    return MAX(minimum, MIN(maximum, value));
}

static CGFloat SFMap(CGFloat value, CGFloat inputMin, CGFloat inputMax, CGFloat outputMin, CGFloat outputMax) {
    CGFloat t = (SFClamp(value, inputMin, inputMax) - inputMin) / (inputMax - inputMin);
    return outputMin + (outputMax - outputMin) * t;
}

@interface SFOverlayView ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CFTimeInterval lastTimestamp;
@property (nonatomic, assign) SFSettingsSnapshot currentSettings;
@property (nonatomic, assign) NSInteger pacingFrameCount;
@property (nonatomic, assign) CFTimeInterval pacingTotal;
@property (nonatomic, assign) CGFloat loadScale;
@end

@implementation SFOverlayView {
    SFSimulation *_simulation;
    std::vector<SFSurface> _surfaces;
}

- (instancetype)initWithFrame:(CGRect)frame simulation:(SFSimulation *)simulation {
    self = [super initWithFrame:frame];
    if (self) {
        _simulation = simulation;
        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = NO;
        self.opaque = NO;
        self.clipsToBounds = YES;
        self.contentMode = UIViewContentModeRedraw;
        _loadScale = 1.0;
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return NO;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    self.displayLink.paused = self.window == nil || !self.currentSettings.enabled;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateSimulationConfig];
}

- (void)start {
    if (!self.displayLink) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkTick:)];
        [self.displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    self.lastTimestamp = 0;
    self.displayLink.paused = self.window == nil || !self.currentSettings.enabled;
}

- (void)stop {
    [self.displayLink invalidate];
    self.displayLink = nil;
    self.lastTimestamp = 0;
}

- (void)applySettings:(SFSettingsSnapshot)settings {
    self.currentSettings = settings;
    [self updateSimulationConfig];
    self.hidden = !settings.enabled;
    self.displayLink.paused = !settings.enabled || self.window == nil;
    [self setNeedsDisplay];
}

- (void)setCollisionSurfaces:(const std::vector<SFSurface>&)surfaces {
    _surfaces = surfaces;
    _simulation->setSurfaces(_surfaces);
}

- (void)clearDeposits {
    _simulation->clearDeposits();
    [self setNeedsDisplay];
}

- (void)updateSimulationConfig {
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat density = SFClamp(self.currentSettings.density, 0.0, 1.0);
    CGFloat speed = SFMap(self.currentSettings.fallSpeed, 0.25, 2.0, 35.0, 180.0);
    CGFloat radius = SFMap(self.currentSettings.particleSize, 0.5, 2.0, 1.5, 6.0);
    CGFloat wind = SFMap(self.currentSettings.wind, -1.0, 1.0, -60.0, 60.0);
    CGFloat meltNormalized = SFMap(self.currentSettings.meltRate, 0.02, 0.5, 0.0, 1.0);
    CGFloat lifetime = 80.0 - 75.0 * meltNormalized;
    NSInteger baseMax = (NSInteger)lrint(20.0 + density * 200.0);
    NSInteger adaptiveMax = MAX(10, (NSInteger)lrint(baseMax * self.loadScale));

    SFSimulationConfig config;
    config.width = width;
    config.height = height;
    config.density = density;
    config.fallSpeed = speed;
    config.particleSize = radius;
    config.wind = wind;
    config.meltRate = lifetime > 0.0 ? 1.0 / lifetime : 0.2;
    config.maxParticles = (int)adaptiveMax;
    config.maxDepositsPerSurface = 48;
    _simulation->setConfig(config);
}

- (void)displayLinkTick:(CADisplayLink *)link {
    if (!self.currentSettings.enabled || self.window == nil) {
        return;
    }

    CFTimeInterval dt = self.lastTimestamp > 0 ? link.timestamp - self.lastTimestamp : link.duration;
    self.lastTimestamp = link.timestamp;
    dt = MIN(dt, 1.0 / 15.0);

    _simulation->update((float)dt);
    [self setNeedsDisplay];

    self.pacingFrameCount += 1;
    self.pacingTotal += dt;
    if (self.pacingFrameCount >= 30) {
        CFTimeInterval average = self.pacingTotal / self.pacingFrameCount;
        CGFloat oldScale = self.loadScale;
        if (average > 1.0 / 40.0) {
            self.loadScale = MAX(0.25, self.loadScale * 0.75);
        } else if (average < 1.0 / 55.0) {
            self.loadScale = MIN(1.0, self.loadScale + 0.05);
        }
        if (fabs(self.loadScale - oldScale) > 0.001) {
            [self updateSimulationConfig];
        }
        self.pacingFrameCount = 0;
        self.pacingTotal = 0;
    }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }

    CGContextSaveGState(context);
    CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:1.0 alpha:0.82].CGColor);

    for (const auto& particle : _simulation->particles()) {
        if (!particle.active) {
            continue;
        }
        CGFloat radius = particle.radius;
        CGRect particleRect = CGRectMake(particle.position.x - radius, particle.position.y - radius, radius * 2.0, radius * 2.0);
        CGContextFillEllipseInRect(context, particleRect);
    }

    for (const auto& deposit : _simulation->deposits()) {
        CGFloat melt = SFClamp(deposit.remaining, 0.0, 1.0);
        CGFloat radius = deposit.radius * melt;
        if (radius <= 0.1) {
            continue;
        }
        CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:1.0 alpha:0.9 * melt].CGColor);
        CGRect depositRect = CGRectMake(deposit.position.x - radius * 1.3, deposit.position.y - radius * 0.65, radius * 2.6, radius * 1.3);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:depositRect cornerRadius:radius * 0.65];
        [path fill];
    }

    CGContextRestoreGState(context);
}

- (void)dealloc {
    [self stop];
}

@end
