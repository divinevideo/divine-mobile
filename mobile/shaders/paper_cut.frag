// The paper cut effect on a still, for its tile in the video editor's
// effects picker.
//
// The renderers draw the effect natively, with `PaperCutVideoEffect` on
// Android, iOS and macOS. This is the same shader: the picture as layers of
// cut coloured paper stacked on each other, the lighter ones on top.
//
// The picture is softened over a ring of taps, so the sheets get smooth,
// rounded edges instead of following every grain and speck, and its
// brightness is cut into four layers. Each sheet has its layer's one
// brightness and keeps the picture's hue there, a little paler, so grey
// stays grey and skin stays skin. Light comes from the top left: a higher
// sheet casts a soft shadow on the ones below, and a sheet's edge facing
// the light catches it. The paper has a faint grain.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side, `e` the softening's radius and the shadow's step in pixels.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the picture turns into paper, 0 to 1.
uniform float uIntensity;

// How many sheets the picture is cut into, 2 to 8.
uniform float uLayers;

// How far the sheets stand apart, which sets how long their shadows are, as
// a share of the default.
uniform float uDepth;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

float grain(vec2 q) {
  return fract(52.9829189 * fract(dot(q, vec2(0.06711056, 0.00583715))));
}

// The picture at `q`, softened over its centre and eight taps on a ring `e`
// around it.
vec3 soft(vec2 q, float e) {
  float d = 0.70710678 * e;
  vec3 ring = tap(q + vec2(e, 0.0)) + tap(q - vec2(e, 0.0)) + tap(q + vec2(0.0, e)) +
    tap(q - vec2(0.0, e)) + tap(q + vec2(d, d)) + tap(q - vec2(d, d)) +
    tap(q + vec2(d, -d)) + tap(q - vec2(d, -d));
  return (tap(q) + ring) / 9.0;
}

// Which of the n layers a colour lies on, 0 the lowest.
float layer(vec3 c, float n) {
  return min(floor(clamp(luma(c), 0.0, 1.0) * n), n - 1.0);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float s = min(uSize.x, uSize.y);
  float e = max(1.5, s / 180.0);
  vec2 toLight = vec2(-0.70710678, 0.70710678) * e * uDepth;
  vec3 here = soft(p, e);
  float h = layer(here, uLayers);
  float near = layer(soft(p + toLight, e), uLayers);
  float far = layer(soft(p + 2.0 * toLight, e), uLayers);
  float shadow = max(step(h + 0.5, near) * 0.7, step(h + 0.5, far) * 0.35);
  float lit = step(near + 0.5, h);
  float l = luma(here);
  vec3 hue = (here - l) * 0.8;
  float sheetLuma = 0.16 + 0.72 * h / (uLayers - 1.0);
  vec3 sheet = clamp(sheetLuma + hue * min(sheetLuma / max(l, 0.05), 1.5), 0.0, 1.0);
  float fibre = 0.97 + 0.03 * grain(floor(p / max(1.0, s / 540.0)));
  vec3 paper = clamp(sheet * (1.0 - 0.4 * shadow) * (1.0 + 0.12 * lit) * fibre, 0.0, 1.0);
  fragColor = vec4(mix(tap(p), paper, uIntensity), 1.0);
}
