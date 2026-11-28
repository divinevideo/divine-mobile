// The fluted glass effect on a still, for its tile in the video editor's
// effects picker.
//
// The renderers draw the effect natively, with `FlutedGlassVideoEffect` on
// Android, iOS and macOS. This is the same shader: ribs, upright and 8% of
// the shorter side wide unless the settings turn or widen them, show a slice
// of the picture wider than themselves, squeezed, and are shaded darker
// towards their edges with a highlight on one side. Slices reaching past an
// edge are mirrored back.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `across` runs from
// -0.5 to 0.5 across a rib, 0 at its middle.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How much the ribs squeeze and shade the picture, 0 to 1.
uniform float uIntensity;

// How wide the ribs are, as a share of the default.
uniform float uRib;

// The direction across the ribs, as a unit vector with y up: (1, 0) for
// upright ribs.
uniform vec2 uAxis;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float rib = 0.08 * uRib * min(uSize.x, uSize.y);
  float across = fract(dot(p - 0.5 * uSize, uAxis) / rib + 0.5) - 0.5;
  vec2 q = abs(p + 1.5 * uIntensity * across * rib * uAxis);
  vec3 color = tap(uSize - abs(uSize - q));
  color *= 1.0 - 0.6 * uIntensity * across * across;
  color += 0.1 * uIntensity * (1.0 - smoothstep(0.0, 0.15, abs(across + 0.22)));
  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
