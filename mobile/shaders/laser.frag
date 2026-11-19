// The laser effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `LaserVideoEffect` on Android,
// iOS and macOS. This is the same shader: seven thin coloured beams fan out
// from just above the middle of the top edge over a slightly dimmed picture.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `l` is the longer
// side. `across` is how far the pixel lies beside a beam, in pixels.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How dim the picture gets and how bright the beams are, 0 to 1.
uniform float uIntensity;

// How far the fan has swung, in seconds of swinging.
uniform float uPhase;

// Which colours the beams show, and how far they have blended into them from
// those of the step before, 0 to 1.
uniform float uStep;
uniform float uMix;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

// Three groups of lights, a third of the hue circle apart, turning round the
// hue circle by the golden angle each step, and a fifth white.
vec3 partyColor(float stage, float group) {
  vec3 hue = fract(0.08 + stage * 0.381966 + group / 3.0 + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0));
  return mix(vec3(1.0), clamp(abs(hue * 6.0 - 3.0) - 1.0, 0.0, 1.0), 0.8);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float l = max(uSize.x, uSize.y);
  vec2 d = p - vec2(0.5 * uSize.x, uSize.y + 0.02 * l);
  float dist = length(d);
  float angle = atan(d.x, -d.y);
  float aim = 0.5 * sin(0.8 * uPhase);
  float spread = 0.14 + 0.05 * sin(0.45 * uPhase + 1.3);
  vec3 first = mix(partyColor(uStep - 1.0, 0.0), partyColor(uStep, 0.0), uMix);
  vec3 second = mix(partyColor(uStep - 1.0, 1.5), partyColor(uStep, 1.5), uMix);
  float core = 0.0022 * l;
  float glow = 0.012 * l;
  vec3 light = vec3(0.0);
  for (int i = 0; i < 7; i++) {
    float across = dist * abs(sin(angle - aim - (float(i) - 3.0) * spread));
    float beam = exp(-across * across / (core * core)) + 0.35 * exp(-across / glow);
    light += beam * mix(first, second, float(i) - 2.0 * floor(float(i) / 2.0));
  }
  float fade = 1.0 / (1.0 + dist / (0.8 * l));
  vec3 base = tap(p);
  vec3 lit = base * (1.0 - 0.35 * uIntensity) + uIntensity * fade * light;
  fragColor = vec4(clamp(lit, 0.0, 1.0), 1.0);
}
