// The ASCII effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `AsciiVideoEffect` on
// Android, iOS and macOS. This is the same shader: the picture redrawn in
// characters on black, in a grid of square cells.
//
// Each cell shows the glyph whose ink matches the cell's brightness, from
// the glyph atlas `tools/generate_ascii_glyphs.dart` writes: ten glyphs of
// 24x24 side by side, emptiest first, read with bilinear filtering. The
// glyph is drawn in the cell's colour brightened to full strength, so the
// glyphs carry the brightness and the colour stays clear.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side and `c` a cell's side, in pixels; the atlas's first row is its top.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the picture turns into characters, 0 to 1.
uniform float uIntensity;

uniform sampler2D uTexture;

// The glyph atlas, with bilinear filtering.
uniform sampler2D uGlyphs;

out vec4 fragColor;

const float kGlyphs = 10.0;
const float kGlyphSize = 24.0;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float s = min(uSize.x, uSize.y);
  float c = max(8.0, s / 60.0);
  vec2 cell = floor(p / c);
  vec2 middle = (cell + 0.5) * c;
  vec3 ink = 0.25 * (tap(middle + vec2(-0.25, -0.25) * c) + tap(middle + vec2(0.25, -0.25) * c) +
    tap(middle + vec2(-0.25, 0.25) * c) + tap(middle + vec2(0.25, 0.25) * c));
  float level = min(floor(luma(ink) * kGlyphs), kGlyphs - 1.0);
  vec2 inCell = p / c - cell;
  vec2 texel = clamp(vec2(inCell.x, 1.0 - inCell.y) * kGlyphSize, 0.5, kGlyphSize - 0.5);
  vec2 atlas = vec2(kGlyphs * kGlyphSize, kGlyphSize);
  float glyph = texture(uGlyphs, vec2(level * kGlyphSize + texel.x, texel.y) / atlas).r;
  float hi = max(max(ink.r, ink.g), ink.b);
  vec3 ascii = clamp(ink / max(hi, 0.25), 0.0, 1.0) * glyph;
  fragColor = vec4(mix(tap(p), ascii, uIntensity), 1.0);
}
