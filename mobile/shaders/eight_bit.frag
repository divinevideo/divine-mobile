// The 8-bit effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `EightBitVideoEffect` on
// Android, iOS and macOS. This is the same shader: chunky pixels in 256
// colours, with an ordered dither between them.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side, `cell` one game pixel's size in texture pixels.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the picture turns into pixel art, 0 to 1.
uniform float uIntensity;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

float bayer(vec2 a) {
  a = floor(a);
  return fract(a.x * 0.5 + a.y * a.y * 0.75);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float s = min(uSize.x, uSize.y);
  float cell = max(1.0, s / 100.0);
  vec2 index = floor(p / cell);
  vec2 centre = (index + 0.5) * cell;
  float q = 0.25 * cell;
  vec3 color = tap(p);
  vec3 block = 0.25 * (tap(centre + vec2(-q, -q)) + tap(centre + vec2(q, -q)) +
    tap(centre + vec2(-q, q)) + tap(centre + vec2(q, q)));
  float threshold = 0.25 * bayer(0.5 * index) + bayer(index);
  vec3 levels = vec3(7.0, 7.0, 3.0);
  vec3 shade = clamp(floor(block * levels + threshold), vec3(0.0), levels) / levels;
  fragColor = vec4(mix(color, shade, uIntensity), 1.0);
}
