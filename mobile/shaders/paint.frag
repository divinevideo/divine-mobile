// The watercolour and oil paint effects on a still, for their tiles in the
// video editor's effects picker.
//
// The renderers draw the effects natively, with `PaintVideoEffect` on
// Android, iOS and macOS. This is the same shader: a soft Kuwahara filter,
// which paints each pixel with the mean colours of the four quadrants around
// it, weighted towards the evenest, so the picture turns into flat patches with
// the edges kept.
//
// Watercolour mixes the quadrants softly, lightens the washes, lets the paint
// pool darker where they meet and shows the paper's grain; oil paint keeps only
// the evenest, for hard edges, and lights the patches' edges from the top left
// like thick paint.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side, `e` the step between the filter's taps: 7 by 7 of them, so the
// patches stay about the same share of the frame at every resolution.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the picture turns into paint, 0 to 1.
uniform float uIntensity;

// 0 for watercolour, 1 for oil paint.
uniform float uStyle;

// How large the brush strokes are, as a share of the default.
uniform float uBrush;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 q) {
  vec3 r = fract(vec3(q.xyx) * 0.1031);
  r += dot(r, r.yzx + 3.33);
  return fract((r.x + r.y) * r.z);
}

// Value noise: the hash on a grid, blended smoothly between its points.
float noise(vec2 q) {
  vec2 i = floor(q);
  vec2 f = q - i;
  f = f * f * (3.0 - 2.0 * f);
  float bottom = mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x);
  float top = mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x);
  return mix(bottom, top, f.y);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float s = min(uSize.x, uSize.y);
  float e = max(1.0, s / 360.0 * uBrush);
  vec3 m0 = vec3(0.0);
  vec3 m1 = vec3(0.0);
  vec3 m2 = vec3(0.0);
  vec3 m3 = vec3(0.0);
  vec4 sum = vec4(0.0);
  vec4 squares = vec4(0.0);
  for (int j = -3; j <= 3; j++) {
    for (int i = -3; i <= 3; i++) {
      vec3 c = tap(p + vec2(float(i), float(j)) * e);
      float l = luma(c);
      float left = step(float(i), 0.0);
      float right = step(0.0, float(i));
      float below = step(float(j), 0.0);
      float above = step(0.0, float(j));
      vec4 w = vec4(left * below, right * below, left * above, right * above);
      m0 += c * w.x;
      m1 += c * w.y;
      m2 += c * w.z;
      m3 += c * w.w;
      sum += w * l;
      squares += w * l * l;
    }
  }
  vec4 mean = sum / 16.0;
  vec4 deviation = sqrt(max(squares / 16.0 - mean * mean, 0.0));
  vec4 k = 1.0 / (1.0 + pow(deviation * 40.0, vec4(mix(3.0, 8.0, uStyle))));
  vec3 painted = (m0 * k.x + m1 * k.y + m2 * k.z + m3 * k.w) / (16.0 * dot(k, vec4(1.0)));
  float lo = min(min(mean.x, mean.y), min(mean.z, mean.w));
  float hi = max(max(mean.x, mean.y), max(mean.z, mean.w));
  float pool = smoothstep(0.06, 0.25, hi - lo);
  float blot = noise(p / (0.12 * s));
  float paper = 0.93 + 0.07 * noise(p / e);
  vec3 pigment = clamp(mix(vec3(luma(painted)), painted, 1.15), 0.0, 1.0);
  vec3 wash = (1.0 - (1.0 - pigment) * (0.8 + 0.15 * blot)) * (1.0 - 0.12 * pool) * paper;
  vec2 slope = vec2(mean.y + mean.w - mean.x - mean.z, mean.z + mean.w - mean.x - mean.y);
  float relief = 1.0 + 0.8 * dot(slope, vec2(-0.70710678, 0.70710678));
  float bristle = noise(vec2(dot(p, vec2(0.8, 0.6)) / e, dot(p, vec2(-0.6, 0.8)) / (6.0 * e)));
  float light = clamp(relief * (0.96 + 0.08 * bristle), 0.85, 1.15);
  vec3 oil = clamp(mix(vec3(luma(painted)), painted, 1.3) * light, 0.0, 1.0);
  vec3 art = mix(wash, oil, uStyle);
  fragColor = vec4(mix(tap(p), art, uIntensity), 1.0);
}
