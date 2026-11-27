// The disco effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `DiscoVideoEffect` on Android,
// iOS and macOS. This is the same shader: coloured spots from a mirror ball
// above the top edge sweep over the picture, which is slightly dimmed around
// them.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `l` is the longer
// side. `turn` is the angle around the ball from straight down, turned with
// the ball, and `cell` the angle from one spot to the next on the pixel's
// ring.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How dim the picture gets and how bright the spots are, 0 to 1.
uniform float uIntensity;

// How far the ball has turned, in seconds of turning.
uniform float uPhase;

// Which colours the spots show, and how far they have blended into them from
// those of the step before, 0 to 1.
uniform float uStep;
uniform float uMix;

// How large the spots are, as a share of the default.
uniform float uSpotSize;

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
  vec2 ball = vec2(0.5 * uSize.x, uSize.y + 0.35 * l);
  vec2 d = p - ball;
  float spacing = 0.085 * l;
  float ring = floor(length(d) / spacing);
  float odd = ring - 2.0 * floor(ring / 2.0);
  float cell = 1.1 / (ring + 0.5);
  float spin = 0.25 * uPhase;
  float turn = atan(d.x, -d.y) + spin;
  float index = floor(turn / cell + 0.5 * odd);
  float centreTurn = (index + 0.5 - 0.5 * odd) * cell - spin;
  vec2 centre = ball + (ring + 0.5) * spacing * vec2(sin(centreTurn), -cos(centreTurn));
  float size = 0.018 * l * uSpotSize * (0.75 + 0.5 * fract(index * 0.618034 + ring * 0.371));
  vec2 q = (p - centre) / size;
  float r2 = dot(q, q);
  float spot = exp(-r2 * r2 * r2);
  float group = index + ring - 3.0 * floor((index + ring) / 3.0);
  vec3 color = mix(partyColor(uStep - 1.0, group), partyColor(uStep, group), uMix);
  vec3 base = tap(p);
  vec3 lit = base * (1.0 - 0.4 * uIntensity) + uIntensity * spot * color * (0.25 + 0.75 * base);
  fragColor = vec4(clamp(lit, 0.0, 1.0), 1.0);
}
