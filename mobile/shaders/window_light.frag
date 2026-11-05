// The window light effect on a still, for its tile in the video editor's
// effects picker.
//
// The renderers draw the effect natively, with `WindowLightVideoEffect` on
// Android, iOS and macOS. This is the same shader: slanted stripes of warm
// light, as through a venetian blind, slide slowly across a soft window patch,
// and the picture between them is a little darker.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How strong the light and the shade are, 0 to 1.
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
  float s = min(uSize.x, uSize.y);
  float slats = fract((p.y + 0.45 * p.x) / (0.12 * s) - 0.11 * uTime);
  float slat = smoothstep(0.0, 0.12, slats) * (1.0 - smoothstep(0.42, 0.56, slats));
  vec2 d = (p / uSize - vec2(0.58, 0.6)) * vec2(1.3, 1.0);
  float window = 1.0 - smoothstep(0.25, 0.75, length(d));
  vec3 shade = vec3(1.0 - 0.35 * uIntensity);
  vec3 warm = 1.0 + uIntensity * vec3(0.7, 0.5, 0.22);
  vec3 base = tap(p);
  fragColor = vec4(clamp(base * mix(shade, warm, slat * window), 0.0, 1.0), 1.0);
}
