// The long exposure on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `LongExposureVideoEffect` on
// Android, iOS and macOS: each pixel takes the brightest of itself and of up
// to six earlier frames, two frames apart, each counted only as far as it is
// bright and fading the further back it lies. A still has no earlier frames,
// so this shader stands the still in for them, shifted as if the picture had
// moved to the right, uShift of its width each frame.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// The effect's intensity, 0 to 1: longer trails, fading slower, and of less
// bright parts.
uniform float uIntensity;

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

vec3 trail(vec3 c, float threshold, float weight) {
  float bright = smoothstep(threshold, threshold + 0.25, dot(c, vec3(0.299, 0.587, 0.114)));
  return c * (bright * weight);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float copies = clamp(floor(2.0 + 4.0 * uIntensity + 0.5), 2.0, 6.0);
  float threshold = 0.7 - 0.25 * uIntensity;
  vec3 color = tap(p);
  for (int k = 0; k < 6; k++) {
    float n = float(k + 1);
    if (n > copies) break;
    float weight = pow(0.7 + 0.25 * uIntensity, n);
    color = max(color, trail(earlier(p, 2.0 * n), threshold, weight));
  }
  fragColor = vec4(color, 1.0);
}
