// The riso print effect on a still, for its tile in the video editor's
// effects picker.
//
// The renderers draw the effect natively, with `RisoVideoEffect` on Android,
// iOS and macOS. This is the same shader: the picture in pink and blue ink on
// off-white paper, grainy and slightly out of register.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side and `g` the grain cell.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the picture turns into the print, 0 to 1.
uniform float uIntensity;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

float grain(vec2 q) {
  return fract(52.9829189 * fract(dot(q, vec2(0.06711056, 0.00583715))));
}

float cover(float density, float threshold) {
  return clamp((density - 0.15 - 0.7 * threshold) / 0.3 + 0.5, 0.0, 1.0);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float s = min(uSize.x, uSize.y);
  vec2 g = floor(p / max(1.0, s / 360.0));
  vec3 color = tap(p);
  vec3 slipped = tap(p + vec2(0.006, -0.004) * s);
  float pink = cover(1.0 - color.g, grain(g));
  float blue = cover(1.0 - slipped.r, grain(g + vec2(19.0, 7.0)));
  vec3 riso = vec3(0.96, 0.94, 0.9) * mix(vec3(1.0), vec3(1.0, 0.28, 0.69), pink) *
    mix(vec3(1.0), vec3(0.0, 0.47, 0.75), blue);
  fragColor = vec4(mix(color, riso, uIntensity), 1.0);
}
