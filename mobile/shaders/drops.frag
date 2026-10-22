// The drops effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `DropsVideoEffect` on Android,
// iOS and macOS. This is the same shader: glass drops that flow into each
// other, bend the picture at their rims with colour fringes, frost it, catch
// a highlight on the top left and cast a shadow.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in and out. `s` is the
// shorter side, and `z` scales everything around the drops' rims with their
// size.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How strongly the glass bends, lights and shades the picture, 0 to 1.
uniform float uIntensity;

// How much larger than at the default size the drops are drawn.
uniform float uScale;

// How frosted the glass is, 0 to 1.
uniform float uFrost;

// How strongly red and blue part at the rims, 0 to 1.
uniform float uFringes;

// Each drop: its centre as fractions of the width and height, up from the
// bottom left, and its radius as a fraction of the shorter side.
uniform vec3 uDrop0;
uniform vec3 uDrop1;
uniform vec3 uDrop2;
uniform vec3 uDrop3;
uniform vec3 uDrop4;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 drops[5];

float smin(float a, float b, float k) {
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

// Signed distance to the glass, negative inside.
float glass(vec2 p, float k) {
  float d = 1e5;
  for (int i = 0; i < 5; i++) {
    d = smin(d, length(p - drops[i].xy) - drops[i].z, k);
  }
  return d;
}

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

vec3 frosted(vec2 q, float r) {
  vec3 sum = tap(q);
  for (int i = 0; i < 8; i++) {
    float n = float(i);
    float angle = n * 2.399963;
    sum += tap(q + r * sqrt((n + 0.5) / 8.0) * vec2(cos(angle), sin(angle)));
  }
  return sum / 9.0;
}

void main() {
  float intensity = uIntensity;
  float z = uScale;
  float frost = uFrost;
  float fringes = uFringes;
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float s = min(uSize.x, uSize.y);
  drops[0] = vec3(uDrop0.xy * uSize, uDrop0.z * s);
  drops[1] = vec3(uDrop1.xy * uSize, uDrop1.z * s);
  drops[2] = vec3(uDrop2.xy * uSize, uDrop2.z * s);
  drops[3] = vec3(uDrop3.xy * uSize, uDrop3.z * s);
  drops[4] = vec3(uDrop4.xy * uSize, uDrop4.z * s);
  float k = 0.13 * s * z;

  vec3 base = tap(p);
  float d = glass(p, k);
  float shadow = 1.0 - smoothstep(0.0, 0.07 * s * z, glass(p + vec2(0.0, 0.018 * s * z), k));
  vec3 background = base * (1.0 - shadow * 0.3 * intensity);
  if (d > 1.0) {
    fragColor = vec4(background, 1.0);
    return;
  }

  vec2 g = vec2(
    glass(p + vec2(1.0, 0.0), k) - glass(p - vec2(1.0, 0.0), k),
    glass(p + vec2(0.0, 1.0), k) - glass(p - vec2(0.0, 1.0), k));
  vec2 n = g / max(length(g), 1e-4);
  float w = 0.11 * s * z;
  float e = 1.0 - clamp(-d / w, 0.0, 1.0);
  float slope = e * e * e * pow(max(1.0 - e * e * e * e, 1e-4), -0.75);
  float bend = slope / sqrt(1.0 + slope * slope);
  vec2 shift = -n * bend * 0.95 * intensity * w;
  float r = 0.028 * s * frost * intensity;
  float spread = 0.28 * fringes;
  vec3 color = vec3(
    frosted(p + shift * (1.0 - spread), r).r,
    frosted(p + shift, r).g,
    frosted(p + shift * (1.0 + spread), r).b);
  color = mix(color, vec3(1.0), (0.05 + 0.12 * frost) * intensity);
  float rim = 1.0 - smoothstep(0.0, 0.014 * s * z, -d);
  float light = dot(n, vec2(-0.5524, 0.8336));
  float lit = max(light, 0.0);
  float back = max(-light, 0.0);
  color += intensity * rim * (0.85 * (lit * lit * lit + 0.45 * back * back * back) + 0.08);
  color = clamp(color, 0.0, 1.0);
  fragColor = vec4(mix(background, color, clamp(0.5 - d, 0.0, 1.0)), 1.0);
}
