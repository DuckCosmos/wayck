
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

    vec4 color1;
    vec4 color2;
};

float roundedBoxSdf(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);

    return min(max(q.x, q.y), 0.0)
        + length(max(q, 0.0)) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 halfSize = itemSize * 0.5;

    float r = clamp(radius, 0.0, min(halfSize.x, halfSize.y));

    float boxDistance = roundedBoxSdf(p - halfSize, halfSize, r);
    float boxAA = max(fwidth(boxDistance), 0.75);

    float boxMask = 1.0 - smoothstep(
        -boxAA,
        boxAA,
        boxDistance
    );

    float t = clamp(p.y / max(itemSize.y, 1.0), 0.0, 1.0);

    float b1 = 3.0 * (1.0 - t) * (1.0 - t) * t;
    float b2 = 3.0 * (1.0 - t) * t * t;

    float waveOffset = waveAmp * (
        -b1 * cos(phase) +
         b2 * sin(phase)
    );

    float edge = itemSize.x * clamp(fillLevel, 0.0, 1.0)
               + waveOffset;

    float edgeAA = max(fwidth(edge - p.x), 0.75);

    float fillMask = smoothstep(
        -edgeAA,
        edgeAA,
        edge - p.x
    );

    vec4 col = mix(
        color1,
        color2,
        clamp(p.x / max(itemSize.x, 1.0), 0.0, 1.0)
    );

    float alpha = boxMask * fillMask * col.a * qt_Opacity;

    fragColor = vec4(col.rgb * alpha, alpha);
}
