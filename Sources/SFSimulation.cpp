#include "SFSimulation.hpp"
#include <algorithm>
#include <cmath>

SFSimulation::SFSimulation(unsigned int seed) : rng_(seed) {
}

void SFSimulation::setConfig(const SFSimulationConfig& config) {
    config_ = config;
}

void SFSimulation::setSurfaces(const std::vector<SFSurface>& surfaces) {
    surfaces_ = surfaces;
    deposits_.erase(
        std::remove_if(
            deposits_.begin(),
            deposits_.end(),
            [this](const SFDeposit& deposit) {
                return std::none_of(
                    surfaces_.begin(),
                    surfaces_.end(),
                    [&deposit](const SFSurface& surface) {
                        return surface.id == deposit.surfaceId;
                    });
            }),
        deposits_.end());
}

void SFSimulation::spawnParticle() {
    if (config_.maxParticles <= 0 || static_cast<int>(particles_.size()) >= config_.maxParticles || config_.width <= 0.0f) {
        return;
    }

    std::uniform_real_distribution<float> xDistribution(0.0f, config_.width);
    SFParticle particle;
    particle.position = {xDistribution(rng_), -config_.particleSize};
    particle.velocity = {config_.wind, config_.fallSpeed};
    particle.radius = config_.particleSize;
    particle.active = true;
    particles_.push_back(particle);
}

void SFSimulation::update(float dt) {
    if (dt <= 0.0f) {
        return;
    }

    float spawnRate = std::max(0.0f, config_.density) * 40.0f;
    spawnAccumulator_ += spawnRate * dt;
    while (spawnAccumulator_ >= 1.0f && static_cast<int>(particles_.size()) < config_.maxParticles) {
        spawnParticle();
        spawnAccumulator_ -= 1.0f;
    }

    for (auto& particle : particles_) {
        const SFVec2 previous = particle.position;
        particle.position.x += particle.velocity.x * dt;
        particle.position.y += particle.velocity.y * dt;

        for (const auto& surface : surfaces_) {
            const float top = surface.rect.y;
            const bool crossedTop = previous.y + particle.radius <= top && particle.position.y + particle.radius >= top;
            const bool withinX = particle.position.x >= surface.rect.x - particle.radius &&
                                 particle.position.x <= surface.rect.x + surface.rect.width + particle.radius;
            if (particle.velocity.y >= 0.0f && crossedTop && withinX) {
                int count = 0;
                SFDeposit* nearest = nullptr;
                float nearestDistance = 0.0f;
                for (auto& deposit : deposits_) {
                    if (deposit.surfaceId != surface.id) {
                        continue;
                    }
                    ++count;
                    const float distance = std::abs(deposit.position.x - particle.position.x);
                    if (nearest == nullptr || distance < nearestDistance) {
                        nearest = &deposit;
                        nearestDistance = distance;
                    }
                }

                if (count < config_.maxDepositsPerSurface || nearest == nullptr) {
                    deposits_.push_back(SFDeposit{surface.id, {particle.position.x, top - particle.radius}, particle.radius, 1.0f});
                } else {
                    nearest->remaining = std::min(1.0f, nearest->remaining + 0.2f);
                    nearest->radius = std::min(nearest->radius + particle.radius * 0.15f, particle.radius * 2.5f);
                }
                particle.active = false;
                break;
            }
        }
    }

    particles_.erase(
        std::remove_if(
            particles_.begin(),
            particles_.end(),
            [this](const SFParticle& particle) {
                return !particle.active ||
                       particle.position.y - particle.radius > config_.height ||
                       particle.position.x + particle.radius < 0.0f ||
                       particle.position.x - particle.radius > config_.width;
            }),
        particles_.end());

    for (auto& deposit : deposits_) {
        deposit.remaining -= std::max(0.0f, config_.meltRate) * dt;
    }

    deposits_.erase(
        std::remove_if(
            deposits_.begin(),
            deposits_.end(),
            [](const SFDeposit& deposit) {
                return deposit.remaining <= 0.0f;
            }),
        deposits_.end());
}

void SFSimulation::clearDeposits() {
    deposits_.clear();
}

const std::vector<SFParticle>& SFSimulation::particles() const {
    return particles_;
}

const std::vector<SFDeposit>& SFSimulation::deposits() const {
    return deposits_;
}
