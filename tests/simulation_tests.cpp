#include <cassert>
#include <cmath>
#include "../Sources/SFTypes.hpp"
#include "../Sources/SFSimulation.hpp"

static SFSimulationConfig baseConfig() {
    return SFSimulationConfig{
        320.0f,
        568.0f,
        1.0f,
        80.0f,
        3.0f,
        30.0f,
        0.2f,
        20,
        48
    };
}

static void testGeometryContains() {
    SFVec2 p{10.0f, 20.0f};
    SFRect r{0.0f, 0.0f, 30.0f, 40.0f};
    assert(r.contains(p));
}

static void testParticleFallsAndDriftsWithWind() {
    SFSimulation simulation(7);
    auto config = baseConfig();
    config.maxParticles = 1;
    simulation.setConfig(config);
    simulation.update(0.1f);
    assert(simulation.particles().size() == 1);
    const auto first = simulation.particles().front().position;
    simulation.update(0.1f);
    const auto second = simulation.particles().front().position;
    assert(second.y > first.y);
    assert(second.x > first.x);
}

static void testParticleBecomesDepositOnSurface() {
    SFSimulation simulation(11);
    auto config = baseConfig();
    config.width = 100.0f;
    config.height = 200.0f;
    config.fallSpeed = 120.0f;
    config.wind = 0.0f;
    config.maxParticles = 1;
    simulation.setConfig(config);
    simulation.setSurfaces({SFSurface{42, SFRect{0.0f, 20.0f, 100.0f, 10.0f}}});
    simulation.update(0.1f);
    assert(simulation.particles().size() == 1);
    simulation.update(0.1f);
    assert(simulation.particles().empty());
    assert(simulation.deposits().size() == 1);
    assert(simulation.deposits().front().surfaceId == 42);
}

static void testDepositsMeltAway() {
    SFSimulation simulation(13);
    auto config = baseConfig();
    config.width = 100.0f;
    config.height = 200.0f;
    config.fallSpeed = 120.0f;
    config.wind = 0.0f;
    config.meltRate = 1.0f;
    config.maxParticles = 1;
    simulation.setConfig(config);
    simulation.setSurfaces({SFSurface{7, SFRect{0.0f, 20.0f, 100.0f, 10.0f}}});
    simulation.update(0.1f);
    simulation.update(0.1f);
    assert(simulation.deposits().size() == 1);
    const float before = simulation.deposits().front().remaining;
    simulation.update(0.25f);
    assert(simulation.deposits().front().remaining < before);
    simulation.update(1.0f);
    assert(simulation.deposits().empty());
}

static void testParticleAndDepositCaps() {
    SFSimulation simulation(17);
    auto config = baseConfig();
    config.width = 120.0f;
    config.height = 200.0f;
    config.density = 1.0f;
    config.fallSpeed = 160.0f;
    config.wind = 0.0f;
    config.meltRate = 0.0f;
    config.maxParticles = 3;
    config.maxDepositsPerSurface = 2;
    simulation.setConfig(config);
    simulation.setSurfaces({SFSurface{9, SFRect{0.0f, 30.0f, 120.0f, 10.0f}}});
    for (int i = 0; i < 100; ++i) {
        simulation.update(0.05f);
        assert(simulation.particles().size() <= 3);
    }
    int depositsForSurface = 0;
    for (const auto& deposit : simulation.deposits()) {
        if (deposit.surfaceId == 9) {
            ++depositsForSurface;
        }
    }
    assert(depositsForSurface <= 2);
}

static void testDepositsDisappearWhenSurfaceDisappears() {
    SFSimulation simulation(19);
    auto config = baseConfig();
    config.width = 100.0f;
    config.height = 200.0f;
    config.fallSpeed = 120.0f;
    config.wind = 0.0f;
    config.meltRate = 0.0f;
    config.maxParticles = 1;
    simulation.setConfig(config);
    simulation.setSurfaces({SFSurface{55, SFRect{0.0f, 20.0f, 100.0f, 10.0f}}});
    simulation.update(0.1f);
    simulation.update(0.1f);
    assert(simulation.deposits().size() == 1);
    simulation.setSurfaces({});
    assert(simulation.deposits().empty());
}

int main() {
    testGeometryContains();
    testParticleFallsAndDriftsWithWind();
    testParticleBecomesDepositOnSurface();
    testDepositsMeltAway();
    testParticleAndDepositCaps();
    testDepositsDisappearWhenSurfaceDisappears();
    return 0;
}
