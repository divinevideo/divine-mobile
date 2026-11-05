// The anamorphic effect on a still, for its tile in the video editor's
// effects picker.
//
// The renderers draw the effect natively, with `AnamorphicVideoEffect` on
// Android, iOS and macOS. This is the same shader: each pixel gathers the
// highlights to its left and right, nearer ones more, and adds them as a blue
// streak with a screen blend.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How long and bright the streaks are, 0 to 1.
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
  float reach = (0.08 + 0.17 * uIntensity) * uSize.x;
  float threshold = 0.85 - 0.1 * uIntensity;
  float jitter = fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
  float streak = 0.0;
  for (int i = 0; i < 48; i++) {
    float x = 2.0 * (float(i) + jitter) / 48.0 - 1.0;
    float w = 1.0 - abs(x);
    float h = max(luma(tap(p + vec2(x * reach, 0.0))) - threshold, 0.0) / (1.0 - threshold);
    streak += h * h * w * w;
  }
  streak *= 3.0 / 48.0;
  vec3 lit = clamp(vec3(0.3, 0.62, 1.0) * (5.0 * streak * uIntensity), 0.0, 1.0);
  vec3 base = tap(p);
  fragColor = vec4(1.0 - (1.0 - base) * (1.0 - lit), 1.0);
}
