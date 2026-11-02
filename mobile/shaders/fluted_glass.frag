// The fluted glass effect on a still, for its tile in the video editor's
// effects picker.
//
// The renderers draw the effect natively, with `FlutedGlassVideoEffect` on
// Android, iOS and macOS. This is the same shader: upright ribs, each 8% of
// the shorter side wide, show a slice of the picture wider than themselves,
// squeezed, and are shaded darker towards their edges with a highlight on
// their left. Slices reaching past the left or right edge are mirrored back.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `across` runs from
// -0.5 to 0.5 across a rib, 0 at its middle.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How much the ribs squeeze and shade the picture, 0 to 1.
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
  float rib = 0.08 * min(uSize.x, uSize.y);
  float across = fract((p.x - 0.5 * uSize.x) / rib + 0.5) - 0.5;
  float x = abs(p.x + 1.5 * uIntensity * across * rib);
  vec3 color = tap(vec2(uSize.x - abs(uSize.x - x), p.y));
  color *= 1.0 - 0.6 * uIntensity * across * across;
  color += 0.1 * uIntensity * (1.0 - smoothstep(0.0, 0.15, abs(across + 0.22)));
  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
