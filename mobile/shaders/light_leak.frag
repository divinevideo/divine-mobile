// The light leak effect on a still, for its tile in the video editor's
// effects picker.
//
// The renderers draw the effect natively, with `LightLeakVideoEffect` on
// Android, iOS and macOS. This is the same shader: three warm lights drift
// along the left and top edges and brighten the picture with a screen blend.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `l` is the longer
// side.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How strong the light is, 0 to 1.
uniform float uIntensity;

// Seconds since the effect started.
uniform float uTime;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

vec3 light(vec2 p, vec2 centre, vec2 reach, vec3 color) {
  vec2 d = (p - centre) / reach;
  return color * exp(-dot(d, d));
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float l = max(uSize.x, uSize.y);
  float t = uTime;
  vec3 base = tap(p);
  vec3 glow =
    light(p, uSize * vec2(-0.06 + 0.16 * sin(0.37 * t + 0.4), 0.62 + 0.3 * sin(0.21 * t + 1.1)),
      l * vec2(0.32, 0.6), vec3(0.95, 0.49, 0.17)) +
    light(p, uSize * vec2(0.45 + 0.4 * sin(0.18 * t + 2.2), 1.04 + 0.08 * sin(0.31 * t + 0.3)),
      l * vec2(0.55, 0.26), vec3(0.75, 0.21, 0.24)) +
    light(p, uSize * vec2(0.18 + 0.42 * sin(0.27 * t + 4.0), 0.8 + 0.18 * sin(0.47 * t + 2.6)),
      l * vec2(0.24, 0.24), vec3(0.55, 0.45, 0.28));
  vec3 leak = clamp(glow * uIntensity, 0.0, 1.0);
  fragColor = vec4(1.0 - (1.0 - base) * (1.0 - leak), 1.0);
}
