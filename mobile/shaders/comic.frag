// The comic effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `ComicVideoEffect` on Android,
// iOS and macOS. This is the same shader: flat poster colours, halftone dots
// in the darker tones and ink outlines.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side, `e` the Sobel filter's step in pixels.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the picture turns into the comic, 0 to 1.
uniform float uIntensity;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float s = min(uSize.x, uSize.y);
  float e = max(1.0, s / 540.0);
  vec3 color = tap(p);
  float tl = luma(tap(p + vec2(-e, e)));
  float tc = luma(tap(p + vec2(0.0, e)));
  float tr = luma(tap(p + vec2(e, e)));
  float ml = luma(tap(p + vec2(-e, 0.0)));
  float mr = luma(tap(p + vec2(e, 0.0)));
  float bl = luma(tap(p + vec2(-e, -e)));
  float bc = luma(tap(p + vec2(0.0, -e)));
  float br = luma(tap(p + vec2(e, -e)));
  float gx = tr + 2.0 * mr + br - tl - 2.0 * ml - bl;
  float gy = tl + 2.0 * tc + tr - bl - 2.0 * bc - br;
  float ink = smoothstep(0.3, 0.8, length(vec2(gx, gy)));
  float l = luma(color);
  vec3 vivid = mix(vec3(l), color, 1.4);
  float band = 0.2 + 0.27 * min(floor(l * 4.0), 3.0);
  vec3 poster = clamp(vivid * band / max(l, 0.04), 0.0, 1.0);
  float cell = 0.018 * s;
  vec2 grid = vec2(p.x + p.y, p.y - p.x) * 0.70710678 / cell;
  vec2 d = (fract(grid) - 0.5) * cell;
  float radius = 0.6 * cell * sqrt(max(0.7 - l, 0.0));
  float spot = clamp(radius - length(d), 0.0, 1.0);
  vec3 comic = poster * (1.0 - 0.35 * spot) * (1.0 - 0.85 * ink);
  fragColor = vec4(mix(color, comic, uIntensity), 1.0);
}
