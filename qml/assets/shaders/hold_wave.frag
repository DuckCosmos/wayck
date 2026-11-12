
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
    int direction;

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

    bool horizontal = direction < 2;

    float axisLength = horizontal ? itemSize.x : itemSize.y;

    float perpendicularLength = horizontal ? itemSize.y : itemSize.x;

    float axisPosition = direction == 0 ? p.x
        : direction == 1 ? itemSize.x - p.x
        : direction == 2 ? itemSize.y - p.y
        : p.y;

    float perpendicularPosition = horizontal ? p.y : p.x;

    float t = clamp(
        perpendicularPosition / max(perpendicularLength, 1.0),
        0.0,
        1.0
    );

    float fillAxis = axisLength * clamp(fillLevel, 0.0, 1.0);

    float b1 = 3.0 * (1.0 - t) * (1.0 - t) * t;
    float b2 = 3.0 * (1.0 - t) * t * t;

    float waveOffset = waveAmp * (
        b2 * sin(phase) - b1 * cos(phase)
    );

    float surfaceAxis = fillAxis + waveOffset;
    float fluidDistance = surfaceAxis - axisPosition;

    float fluidAlpha = clamp(
        0.5 + fluidDistance,
        0.0,
        1.0
    );

    float gradient = clamp(
        axisPosition / max(axisLength, 1.0),
        0.0,
        1.0
    );

    vec4 col = mix(color1, color2, gradient);
    vec4 backCol = mix(color1, color2, gradient);

    float backAlpha = 0.0;

    if (threeDimensional > 0.5) {
        float backWaveOffset = -waveOffset * 0.72;

        float backSurfaceAxis = fillAxis + backWaveOffset + 3.0;

        float backDistance = backSurfaceAxis - axisPosition;

        backAlpha = clamp(
            0.5 + backDistance,
            0.0,
            1.0
        );

        backCol.rgb *= 0.58;

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

        float surfaceSlope = horizontal
            ? dFdy(surfaceAxis)
            : dFdx(surfaceAxis);

        float slopeShade = clamp(
            1.0 - abs(surfaceSlope) * 0.0025,
            0.88,
            1.0
        );

        col.rgb *= (1.0 - edgeShadow * 0.27) * slopeShade;
        col.rgb += col.rgb * edgeHighlight * 0.17;
    }

    float frontAlpha = fluidAlpha * col.a;
    float rearAlpha = backAlpha * backCol.a;

    vec3 composedRgb =
        col.rgb * frontAlpha +
        backCol.rgb * rearAlpha * (1.0 - frontAlpha);

    float composedAlpha =
        frontAlpha +
        rearAlpha * (1.0 - frontAlpha);

    float finalAlpha = composedAlpha * boxAlpha * qt_Opacity;

    composedRgb *= boxAlpha * qt_Opacity;

    fragColor = vec4(composedRgb, finalAlpha);
}
