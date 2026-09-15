#!/usr/bin/env bash
set -euo pipefail
mkdir -p .build-tests
c++ -std=c++17 -Wall -Wextra -Werror tests/simulation_tests.cpp Sources/SFSimulation.cpp -o .build-tests/simulation_tests
.build-tests/simulation_tests
