
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;

    float radius;
    float fillLevel;
    float waveAmp;
    vec2 itemSize;
    float phase;
    float threeDimensional;

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

    // Rounded box clipping.
    float clampedRadius = clamp(
        radius,
        0.0,
        min(halfSize.x, halfSize.y)
    );

    float boxDistance = sdRoundedBox(
        p - halfSize,
        halfSize,
        clampedRadius
    );

    float boxAlpha = clamp(0.5 - boxDistance, 0.0, 1.0);

    // Main fluid surface.
    float fillX = itemSize.x * clamp(fillLevel, 0.0, 1.0);
    float t = clamp(p.y / max(itemSize.y, 1.0), 0.0, 1.0);

    float b1 = 3.0 * (1.0 - t) * (1.0 - t) * t;
    float b2 = 3.0 * (1.0 - t) * t * t;

    float waveOffset = waveAmp * (
        b2 * sin(phase) - b1 * cos(phase)
    );

    float surfaceX = fillX + waveOffset;
    float fluidDistance = surfaceX - p.x;

    float fluidAlpha = clamp(
        0.5 + fluidDistance,
        0.0,
        1.0
    );

    // Color gradient.
    float gradient = clamp(
        p.x / max(itemSize.x, 1.0),
        0.0,
        1.0
    );

    vec4 col = mix(color1, color2, gradient);
    vec4 backCol = mix(color1, color2, gradient);

    // Back fluid surface.
    float backAlpha = 0.0;

    if (threeDimensional > 0.5) {
        // Opposite movement relative to the main wave.
        float backWaveOffset = -waveOffset * 0.72;

        // Small horizontal displacement to expose the depth.
        float backSurfaceX = fillX + backWaveOffset + 3.0;

        float backDistance = backSurfaceX - p.x;

        backAlpha = clamp(
            0.5 + backDistance,
            0.0,
            1.0
        );

        // Darker rear layer.
        backCol.rgb *= 0.58;

        // Main surface shading.
        float edgeShadow = 1.0 - smoothstep(
            0.0,
            4.0,
            fluidDistance
        );

        float edgeHighlight = 1.0 - smoothstep(
            0.0,
            1.25,
            abs(fluidDistance - 2.0)
        );

        float surfaceSlope = dFdy(surfaceX);

        float slopeShade = clamp(
            1.0 - abs(surfaceSlope) * 0.0025,
            0.88,
            1.0
        );

        col.rgb *= (1.0 - edgeShadow * 0.27) * slopeShade;
        col.rgb += col.rgb * edgeHighlight * 0.17;
    }

    // Front and rear layer composition.
    float frontAlpha = fluidAlpha * col.a;
    float rearAlpha = backAlpha * backCol.a;

    vec3 composedRgb =
        col.rgb * frontAlpha +
        backCol.rgb * rearAlpha * (1.0 - frontAlpha);

    float composedAlpha =
        frontAlpha +
        rearAlpha * (1.0 - frontAlpha);

    // Rounded clipping and Qt opacity.
    float finalAlpha = composedAlpha * boxAlpha * qt_Opacity;

    composedRgb *= boxAlpha * qt_Opacity;

    fragColor = vec4(composedRgb, finalAlpha);
}
