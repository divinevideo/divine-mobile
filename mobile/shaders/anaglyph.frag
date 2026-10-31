// The 3D glasses effect on a still, for its tile in the video editor's
// effects picker.
//
// The renderers draw the effect natively, with `AnaglyphVideoEffect` on
// Android, iOS and macOS. This is the same shader: a red copy of the picture
// moved right and a cyan copy moved left, as in a red-cyan anaglyph.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far apart the copies are and how far the colours turn red and cyan,
// 0 to 1.
uniform float uIntensity;

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
  vec2 shift = vec2(0.014 * s * uIntensity, 0.0);
  vec3 color = tap(p);
  vec3 left = tap(p - shift);
  vec3 right = tap(p + shift);
  vec3 stereo = vec3(mix(luma(left), left.r, 0.3), mix(vec2(luma(right)), right.gb, 0.3));
  fragColor = vec4(mix(color, stereo, uIntensity), 1.0);
}
