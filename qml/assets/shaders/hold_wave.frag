#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    // Keep the existing WaveFill.qml interface unchanged.
    float radius;
    float fillLevel;
    float waveAmp;
    vec2 itemSize;
    float phase;

    vec4 color1;
    vec4 color2;
};

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    if (fillLevel <= 0.0001) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 p = qt_TexCoord0 * itemSize;
    vec2 halfSize = itemSize * 0.5;

    float clampedRadius = clamp(radius, 0.0, min(halfSize.x, halfSize.y));
    float boxDistance = sdRoundedBox(p - halfSize, halfSize, clampedRadius);
    float boxAlpha = clamp(0.5 - boxDistance, 0.0, 1.0);

    // Horizontal fluid surface, matching Serpantinum's fluid_wave shader.
    float fillX = itemSize.x * clamp(fillLevel, 0.0, 1.0);
    float t = clamp(p.y / max(itemSize.y, 1.0), 0.0, 1.0);

    float b1 = 3.0 * (1.0 - t) * (1.0 - t) * t;
    float b2 = 3.0 * (1.0 - t) * t * t;

    float waveOffset = waveAmp * (
        b2 * sin(phase) - b1 * cos(phase)
    );

    float surfaceX = fillX + waveOffset;
    float fluidAlpha = clamp(0.5 - (p.x - surfaceX), 0.0, 1.0);

    vec4 col = mix(
        color1,
        color2,
        clamp(p.x / max(itemSize.x, 1.0), 0.0, 1.0)
    );

    float alpha = boxAlpha * fluidAlpha * col.a * qt_Opacity;
    fragColor = vec4(col.rgb * alpha, alpha);
}
