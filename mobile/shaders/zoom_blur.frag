// The zoom blur effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `ZoomBlurVideoEffect` on
// Android, iOS and macOS. This is the same shader: each pixel averages taps
// along the line from it towards the centre.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How long the streaks are, 0 to 1.
uniform float uStrength;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  if (uStrength <= 0.0) {
    fragColor = vec4(tap(p), 1.0);
    return;
  }
  vec2 c = uSize * 0.5;
  float jitter = fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
  vec3 color = vec3(0.0);
  for (int i = 0; i < 32; i++) {
    float share = (float(i) + jitter) / 32.0;
    color += tap(c + (p - c) * (1.0 - 0.22 * uStrength * share));
  }
  fragColor = vec4(color / 32.0, 1.0);
}
