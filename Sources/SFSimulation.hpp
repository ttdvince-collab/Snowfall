#pragma once

#include <random>
#include <vector>
#include "SFTypes.hpp"

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

private:
    void spawnParticle();

    SFSimulationConfig config_{};
    std::vector<SFParticle> particles_;
    std::vector<SFDeposit> deposits_;
    std::vector<SFSurface> surfaces_;
    std::mt19937 rng_;
    float spawnAccumulator_ = 0.0f;
};
