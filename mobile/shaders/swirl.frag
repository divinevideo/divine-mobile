// The swirl effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `SwirlVideoEffect` on Android,
// iOS and macOS. This is the same shader: each pixel samples the picture
// turned around the centre, by up to 3 radians there and by nothing from half
// the shorter side out, falling off with the square of the distance.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the middle turns, 0 to 1.
uniform float uIntensity;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  vec2 c = uSize * 0.5;
  vec2 d = p - c;
  float w = max(1.0 - length(d) / (0.5 * min(uSize.x, uSize.y)), 0.0);
  float angle = 3.0 * uIntensity * w * w;
  float co = cos(angle);
  float si = sin(angle);
  vec3 color = tap(c + vec2(co * d.x - si * d.y, si * d.x + co * d.y));
  fragColor = vec4(color, 1.0);
}
