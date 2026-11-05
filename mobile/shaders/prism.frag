// The prism effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `PrismVideoEffect` on Android,
// iOS and macOS. This is the same shader: a rainbow band drifts across the
// top-right corner, the picture under it splits into red and blue edges
// across the band, and the rainbow is added with a screen blend.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `l` is the longer
// side.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How strong the rainbow is, 0 to 1.
uniform float uIntensity;

// Seconds since the effect started.
uniform float uTime;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float l = max(uSize.x, uSize.y);
  vec2 uv = p / uSize;
  float across = 0.45 * uv.x + 0.55 * uv.y;
  float centre = 0.72 + 0.06 * sin(0.31 * uTime + 1.3);
  float width = 0.14 + 0.02 * sin(0.23 * uTime + 0.4);
  float b = (across - centre) / width;
  float band = 1.0 - smoothstep(0.55, 1.0, abs(b));
  float hue = 0.375 * (b + 1.0);
  vec3 rainbow = clamp(abs(fract(hue + vec3(1.0, 0.6667, 0.3333)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
  vec2 shift = normalize(vec2(0.45 / uSize.x, 0.55 / uSize.y)) * (0.008 * l * uIntensity * band);
  vec3 base = vec3(tap(p + shift).r, tap(p).g, tap(p - shift).b);
  vec3 lit = clamp(rainbow * (0.75 * band * uIntensity), 0.0, 1.0);
  fragColor = vec4(1.0 - (1.0 - base) * (1.0 - lit), 1.0);
}
