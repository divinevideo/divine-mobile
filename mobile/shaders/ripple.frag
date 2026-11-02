// The ripple effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `RippleVideoEffect` on
// Android, iOS and macOS. This is the same shader: rings spread out from the
// centre, pushing each pixel towards or away from it and lighting one side of
// every crest. The phase is kept within one turn, where the GPU's sine and
// cosine are exact enough to match the native copies.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the rings push the picture, 0 to 1.
uniform float uIntensity;

// Seconds since the effect started.
uniform float uTime;

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
  float r = length(d);
  float s = min(uSize.x, uSize.y);
  float phase = 6.2832 * fract(r / (0.1 * s) - fract(uTime * 0.75));
  float fade = smoothstep(0.0, 0.2 * s, r);
  float push = 0.012 * s * uIntensity * fade * sin(phase);
  vec2 q = c + d * (1.0 - 0.025 * uIntensity) + d / max(r, 0.001) * push;
  vec3 color = tap(q) * (1.0 + 0.12 * uIntensity * fade * cos(phase));
  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
