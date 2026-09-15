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
