// Motion only on a still, for its tile in the video editor's effects picker.
//
// The renderers draw the effect natively, with `MotionOnlyVideoEffect` on
// Android, iOS and macOS, from the difference to the frame before. A still
// has no frame before, so this shader stands the still in for it, shifted as
// if the picture had moved to the right by uShift of its width: its edges
// differ, and glow, as a moving subject's do.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How dark the still parts go and how much the moving parts glow, 0 to 1.
uniform float uIntensity;

// How far the picture moves each frame, as a share of its width.
uniform float uShift;

// How far the change that counts as movement is scaled: 1 at the default
// sensitivity, smaller as it rises.
uniform float uSpread;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  vec3 now = tap(p);
  vec3 before = tap(p + vec2(uShift * uSize.x, 0.0));
  float moved = smoothstep(0.05 * uSpread, 0.15 * uSpread, length(now - before));
  vec3 glow = min(now * (1.0 + 0.5 * uIntensity) + 0.1 * uIntensity, vec3(1.0));
  fragColor = vec4(mix(now * (1.0 - uIntensity), glow, moved), 1.0);
}
