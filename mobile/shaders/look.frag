// A colour-graded look on a still, for its tile in the video editor's
// effects picker.
//
// The renderers draw the looks natively, with `LookVideoEffect` on Android,
// iOS and macOS, from the same table, and this is the Android shader's
// lookup line for line. Each colour is looked up in the look's 33x33x33
// table, a strip of 33 slices of 33x33, one per blue level, with red growing
// to the right and green downwards (see `tools/generate_looks.dart`). Red
// and green interpolate within a slice through the texture's bilinear
// filtering, and blue between the two nearest slices, which together is the
// trilinear interpolation Core Image's `CIColorCube` does on iOS and macOS.
//
// The lookup and the mix run on the sRGB-encoded values, as natively.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How much of the look shows, 0 to 1.
uniform float uIntensity;

uniform sampler2D uTexture;

// The look's table, with bilinear filtering.
uniform sampler2D uTable;

out vec4 fragColor;

const float kPoints = 33.0;

vec3 lookUp(vec3 color) {
  vec3 p = clamp(color, 0.0, 1.0) * (kPoints - 1.0);
  float lower = floor(p.b);
  float upper = min(lower + 1.0, kPoints - 1.0);
  vec2 texel = p.rg + 0.5;
  vec2 tableSize = vec2(kPoints * kPoints, kPoints);
  vec3 a = texture(uTable, vec2(lower * kPoints + texel.x, texel.y) / tableSize).rgb;
  vec3 b = texture(uTable, vec2(upper * kPoints + texel.x, texel.y) / tableSize).rgb;
  return mix(a, b, p.b - lower);
}

void main() {
  vec3 color = texture(uTexture, FlutterFragCoord().xy / uSize).rgb;
  fragColor = vec4(mix(color, lookUp(color), uIntensity), 1.0);
}
