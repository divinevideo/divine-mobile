// The time split on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `TimeSplitVideoEffect` on
// Android, iOS and macOS: red from the current frame, green from the frame
// 100 ms earlier and blue from the one 200 ms earlier. A still has no earlier
// frames, so this shader stands the still in for them, shifted as if the
// picture had moved to the right, uShift of its width each frame; the colours
// split as the native shader splits them.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the colours split, 0 to 1.
uniform float uStrength;

// How far the picture moves each frame, as a share of its width.
uniform float uShift;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

// The frame `frames` frames before the current one.
vec3 earlier(vec2 p, float frames) {
  return tap(p + vec2(frames * uShift * uSize.x, 0.0));
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  vec3 now = tap(p);
  vec3 split = vec3(now.r, earlier(p, 3.0).g, earlier(p, 6.0).b);
  fragColor = vec4(mix(now, split, uStrength), 1.0);
}
