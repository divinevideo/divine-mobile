// The cross-stitch effect on a still, for its tile in the video editor's
// effects picker.
//
// The renderers draw the effect natively, with `CrossStitchVideoEffect` on
// Android, iOS and macOS. This is the same shader: the picture embroidered
// in cross stitches on off-white cloth.
//
// Each cell of the cloth holds one stitch, two strands of thread crossing
// from corner to corner, in the mean colour of four taps inside the cell, a
// little more colourful and cut to seven levels a channel, as a set of
// threads holds a limited choice of colours. Each strand is rounded and
// twisted, the top one runs from the top left to the bottom right, and both
// shade the cloth beside them. The cloth shows between the stitches, with
// a hole at every corner where the needle went through.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side and `c` a cell's side in pixels; `inCell` is the place within a cell,
// `w` half a strand's width and `aa` one pixel, all in cells. Each twist
// keeps its phase within one turn, where the GPU's sine stays exact.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the picture turns into embroidery, 0 to 1.
uniform float uIntensity;

// How large the stitches are, as a share of the default.
uniform float uStitch;

// The colour of the cloth between them.
uniform vec3 uCloth;

uniform sampler2D uTexture;

out vec4 fragColor;

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
  float c = max(6.0, s / 36.0 * uStitch);
  vec2 cell = floor(p / c);
  vec2 middle = (cell + 0.5) * c;
  vec3 ink = 0.25 * (tap(middle + vec2(-0.25, -0.25) * c) + tap(middle + vec2(0.25, -0.25) * c) +
    tap(middle + vec2(-0.25, 0.25) * c) + tap(middle + vec2(0.25, 0.25) * c));
  vec3 floss = floor(clamp(mix(vec3(luma(ink)), ink, 1.15), 0.0, 1.0) * 6.0 + 0.5) / 6.0;
  vec2 inCell = p / c - cell;
  float aa = 1.0 / c;
  float w = 0.2;
  float under = abs(inCell.x - inCell.y) * 0.70710678;
  float over = abs(inCell.x + inCell.y - 1.0) * 0.70710678;
  float ends = max(abs(inCell.x - 0.5), abs(inCell.y - 0.5));
  float inside = 1.0 - smoothstep(0.47 - aa, 0.47 + aa, ends);
  float underMask = (1.0 - smoothstep(w - aa, w + aa, under)) * inside;
  float overMask = (1.0 - smoothstep(w - aa, w + aa, over)) * inside;
  float underTwist = 0.9 + 0.1 * sin(6.2831853 * fract((inCell.x + inCell.y) * 2.5));
  float overTwist = 0.9 + 0.1 * sin(6.2831853 * fract((inCell.x - inCell.y) * 2.5));
  float underRound = 1.0 - 0.25 * min(under / w, 1.0) * min(under / w, 1.0);
  float overRound = 1.0 - 0.25 * min(over / w, 1.0) * min(over / w, 1.0);
  float beside = max(1.0 - smoothstep(w, w + 0.08, under), 1.0 - smoothstep(w, w + 0.08, over));
  vec2 hole = inCell - floor(inCell + 0.5);
  float holes = smoothstep(0.04, 0.09, length(hole));
  vec3 cloth = uCloth * (0.7 + 0.3 * holes) * (1.0 - 0.25 * beside * inside);
  vec3 stitch = mix(cloth, floss * underTwist * underRound, underMask);
  stitch = mix(stitch, floss * overTwist * overRound * 1.05, overMask);
  fragColor = vec4(mix(tap(p), clamp(stitch, 0.0, 1.0), uIntensity), 1.0);
}
