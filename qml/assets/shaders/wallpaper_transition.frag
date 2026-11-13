
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float progress;
    float transitionType;
    vec2 origin;
    vec4 params;
};

float hash(vec2 p) {
    return fract(
        sin(dot(p, vec2(127.1, 311.7))) * 43758.5453
    );
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    f = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;

    float t = clamp(progress, 0.0, 1.0);
    float edge = 0.0;

    if (transitionType < 0.5) {
        edge = t;
    }

    else if (transitionType < 1.5) {
        float distanceFromCenter;

        if (params.x > 0.5)
            distanceFromCenter = abs(p.y - itemSize.y * 0.5);
        else
            distanceFromCenter = abs(p.x - itemSize.x * 0.5);

        float maxDistance = params.x > 0.5
            ? itemSize.y * 0.5
            : itemSize.x * 0.5;

        edge = clamp(
            t * maxDistance - distanceFromCenter + 1.0,
            0.0,
            1.0
        );
    }

    else if (transitionType < 2.5) {
        vec2 center = origin * itemSize;

        float maxRadius = max(
            max(length(center), length(vec2(itemSize.x - center.x, center.y))),
            max(length(vec2(center.x, itemSize.y - center.y)), length(itemSize - center))
        );

        float radius = t * maxRadius;

        edge = clamp(
            radius - length(p - center) + 1.0,
            0.0,
            1.0
        );
    }

    else if (transitionType < 3.5) {
        int direction = int(params.y + 0.5);

        float distance = 0.0;
        float total = 1.0;

        if (direction == 0) {
            distance = p.x;
            total = itemSize.x;
        } else if (direction == 1) {
            distance = itemSize.x - p.x;
            total = itemSize.x;
        } else if (direction == 2) {
            distance = p.y;
            total = itemSize.y;
        } else if (direction == 3) {
            distance = itemSize.y - p.y;
            total = itemSize.y;
        } else {
            vec2 start;
            vec2 dir;

            if (direction == 4) {
                start = vec2(0.0, 0.0);
                dir = normalize(itemSize);
            } else if (direction == 5) {
                start = vec2(itemSize.x, 0.0);
                dir = normalize(vec2(-itemSize.x, itemSize.y));
            } else if (direction == 6) {
                start = vec2(0.0, itemSize.y);
                dir = normalize(vec2(itemSize.x, -itemSize.y));
            } else {
                start = itemSize;
                dir = normalize(-itemSize);
            }

            distance = dot(p - start, dir);
            total = length(itemSize);
        }

        edge = clamp(
            t * total - distance + 1.0,
            0.0,
            1.0
        );
    }

    else {
        vec2 cell = floor(p / 5.0);
        float n = noise(cell * 0.12);

        float arrival = n * 0.65 +
            length(p / itemSize - origin) * 0.35;

        edge = smoothstep(
            arrival - 0.035,
            arrival + 0.035,
            t
        );
    }

    fragColor = vec4(1.0, 1.0, 1.0, edge) * qt_Opacity;
}
