#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uSharpen;
uniform float uDeblock;
uniform sampler2D uTexture;

out vec4 fragColor;

vec3 sampleColor(vec2 uv) {
  return texture(
    uTexture,
    clamp(uv, vec2(0.0), vec2(1.0))
  ).rgb;
}

vec3 deblock(vec2 uv, vec2 texel) {
  vec3 center = sampleColor(uv);
  vec3 left = sampleColor(uv - vec2(texel.x, 0.0));
  vec3 right = sampleColor(uv + vec2(texel.x, 0.0));
  vec3 up = sampleColor(uv - vec2(0.0, texel.y));
  vec3 down = sampleColor(uv + vec2(0.0, texel.y));

  vec3 horizontal = (left + center + right) / 3.0;
  vec3 vertical = (up + center + down) / 3.0;
  float edge = max(length(right - left), length(down - up));

  float smoothFactor =
      uDeblock * (1.0 - smoothstep(0.025, 0.14, edge));

  return mix(
    center,
    mix(horizontal, vertical, 0.5),
    smoothFactor
  );
}

float cubicWeight(float distance) {
  float x = abs(distance);

  if (x <= 1.0) {
    return 1.5 * x * x * x - 2.5 * x * x + 1.0;
  }

  if (x < 2.0) {
    return -0.5 * x * x * x +
        2.5 * x * x -
        4.0 * x +
        2.0;
  }

  return 0.0;
}

vec3 bicubic(vec2 uv, vec2 texel) {
  vec2 pixel = uv / texel;
  vec2 basePixel = floor(pixel);
  vec2 fraction = pixel - basePixel;

  vec3 result = vec3(0.0);
  float total = 0.0;

  for (int y = -1; y <= 2; y++) {
    for (int x = -1; x <= 2; x++) {
      vec2 sampleUv =
          (basePixel + vec2(float(x), float(y)) + 0.5) *
          texel;

      float weightX = cubicWeight(float(x) - fraction.x);
      float weightY = cubicWeight(float(y) - fraction.y);
      float weight = weightX * weightY;

      result += sampleColor(sampleUv) * weight;
      total += weight;
    }
  }

  return result / max(total, 0.0001);
}

void main() {
  vec2 texel = 1.0 / uResolution;
  vec2 uv = FlutterFragCoord().xy / uResolution;

  vec3 base = bicubic(uv, texel);

  vec3 blur = (
    sampleColor(uv - vec2(texel.x, 0.0)) +
    sampleColor(uv + vec2(texel.x, 0.0)) +
    sampleColor(uv - vec2(0.0, texel.y)) +
    sampleColor(uv + vec2(0.0, texel.y))
  ) * 0.25;

  vec3 enhanced = base + (base - blur) * uSharpen;

  enhanced = mix(
    enhanced,
    deblock(uv, texel),
    uDeblock * 0.35
  );

  fragColor = vec4(
    clamp(enhanced, 0.0, 1.0),
    1.0
  );
}
