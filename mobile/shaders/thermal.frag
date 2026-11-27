// The thermal camera effect on a still, for its tile in the video editor's
// effects picker.
//
// The renderers draw the effect natively, with `ThermalVideoEffect` on
// Android, iOS and macOS. This is the same shader: the picture as a thermal
// camera shows it, from cold black and purple through red and orange to hot
// yellow and white.
//
// A camera cannot see heat, so the warmth is mostly how much redder than
// green and blue the picture is, plus some of its brightness: skin, lips and
// warm lights run hot, pale walls lukewarm, and blue, green and dark things
// cold. A thermal camera's picture is soft, so the warmth is averaged over
// five taps first, then stretched and run through an ironbow palette.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side, `e` the taps' distance in pixels.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the picture turns into the thermal view, 0 to 1.
uniform float uIntensity;

// How warm a spot must be to glow: 0.5 is the default, higher glows sooner.
uniform float uSensitivity;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

float warmth(vec3 c) {
  return 0.3 * dot(c, vec3(0.299, 0.587, 0.114)) + 1.6 * max(c.r - 0.5 * (c.g + c.b), 0.0);
}

vec3 ironbow(float t) {
  vec3 c = mix(vec3(0.0, 0.0, 0.12), vec3(0.35, 0.0, 0.55), clamp(t / 0.25, 0.0, 1.0));
  c = mix(c, vec3(0.85, 0.1, 0.25), clamp((t - 0.25) / 0.25, 0.0, 1.0));
  c = mix(c, vec3(1.0, 0.5, 0.0), clamp((t - 0.5) / 0.2, 0.0, 1.0));
  c = mix(c, vec3(1.0, 0.85, 0.1), clamp((t - 0.7) / 0.15, 0.0, 1.0));
  return mix(c, vec3(1.0, 1.0, 0.9), clamp((t - 0.85) / 0.15, 0.0, 1.0));
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float s = min(uSize.x, uSize.y);
  float e = max(1.0, s / 270.0);
  vec3 color = tap(p);
  float heat = (2.0 * warmth(color) + warmth(tap(p + vec2(e, 0.0))) +
    warmth(tap(p - vec2(e, 0.0))) + warmth(tap(p + vec2(0.0, e))) +
    warmth(tap(p - vec2(0.0, e)))) / 6.0;
  float shift = 0.6 * (uSensitivity - 0.5);
  vec3 thermal = ironbow(smoothstep(0.1 - shift, 0.75 - shift, heat));
  fragColor = vec4(mix(color, thermal, uIntensity), 1.0);
}
