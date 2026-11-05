// The light rays effect on a still, for its tile in the video editor's
// effects picker.
//
// The renderers draw the effect natively, with `LightRaysVideoEffect` on
// Android, iOS and macOS. This is the same shader: a sun drifts just above the
// top edge, the bright parts of the picture streak towards it, and the light
// is added warm with a screen blend.
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

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float l = max(uSize.x, uSize.y);
  vec2 sun = uSize * vec2(0.3 + 0.25 * sin(0.23 * uTime + 0.8), 1.06);
  vec2 toSun = sun - p;
  float jitter = fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
  vec3 rays = vec3(0.0);
  for (int i = 0; i < 32; i++) {
    float share = (float(i) + jitter) / 32.0;
    vec3 c = tap(p + toSun * (0.5 * share));
    rays += c * (smoothstep(0.7, 1.0, luma(c)) * (1.0 - share));
  }
  vec2 d = toSun / l;
  float sunGlow = exp(-5.0 * dot(d, d));
  vec3 glow = vec3(1.0, 0.86, 0.62) * (rays * (2.0 / 16.0) + 0.35 * sunGlow);
  vec3 lit = clamp(glow * uIntensity, 0.0, 1.0);
  vec3 base = tap(p);
  fragColor = vec4(1.0 - (1.0 - base) * (1.0 - lit), 1.0);
}
