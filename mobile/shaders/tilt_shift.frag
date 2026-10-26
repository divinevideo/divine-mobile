// The tilt-shift effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `TiltShiftVideoEffect` on
// Android, iOS and macOS. This is the same shader: the top and bottom blur
// while a band across the middle stays sharp, and the colours lift.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How strongly the edges blur and the colours lift, 0 to 1.
uniform float uIntensity;

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
  float away = abs(p.y / uSize.y - 0.5);
  float r = 0.03 * s * uIntensity * smoothstep(0.1, 0.42, away);
  vec3 color = tap(p);
  if (r > 0.5) {
    float spin = 6.2832 * fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
    for (int i = 0; i < 32; i++) {
      float n = float(i);
      float angle = n * 2.399963 + spin;
      color += tap(p + r * sqrt((n + 0.5) / 32.0) * vec2(cos(angle), sin(angle)));
    }
    color /= 33.0;
  }
  float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  color = mix(vec3(luma), color, 1.0 + 0.4 * uIntensity);
  color = (color - 0.5) * (1.0 + 0.12 * uIntensity) + 0.5;
  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
