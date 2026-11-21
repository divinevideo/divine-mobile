// The time warp on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `TimeWarpVideoEffect` on
// Android, iOS and macOS: each band of the picture comes from a moment two
// frames further back than the band above it. A still has no earlier frames,
// so this shader stands the still in for them, shifted as if the picture had
// moved to the right, uShift of its width each frame; the bands step sideways
// as a moving subject bends.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How many bands back the bottom of the picture lies, 0 to 7.
uniform float uDepth;

// How far the picture moves each frame, as a share of its width.
uniform float uShift;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

// How much of band k a pixel t bands down shows: all of it near the band's
// middle, none from a whole band away, and in between the weights of two
// neighbouring bands add up to 1.
float band(float t, float k) {
  return 1.0 - smoothstep(0.35, 0.65, abs(t - k));
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float t = (1.0 - p.y / uSize.y) * uDepth;
  vec3 color = vec3(0.0);
  for (int k = 0; k < 8; k++) {
    float frames = 2.0 * float(k);
    color += tap(p + vec2(frames * uShift * uSize.x, 0.0)) * band(t, float(k));
  }
  fragColor = vec4(color, 1.0);
}
