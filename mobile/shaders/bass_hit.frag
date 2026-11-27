// The shockwave and subwoofer effects on a still, for their tiles in the
// video editor's effects picker.
//
// The renderers draw the effects natively, with `BassHitVideoEffect` on
// Android, iOS and macOS. This is the same shader: a hit [uAge] seconds ago
// sends a ring of pressure out from [uCenter] that bends the picture like a
// lens and splits its colours, and races out past the farthest corner
// (shockwave), or bulges the picture there out like a speaker cone that
// springs back (subwoofer). Either way the picture rattles and punches in,
// and is zoomed in by just enough to keep its edges hidden.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How hard the hit lands, 0 to 1.
uniform float uIntensity;

// Seconds into the hit's animation, 0 to 0.5.
uniform float uAge;

// 0 for the shockwave, 1 for the subwoofer.
uniform float uStyle;

// How far the ring travels, or how large the cone is, 0.2 to 1.
uniform float uReach;

// Where the hit comes from, in shares of the frame from its top left.
uniform vec2 uCenter;

// How hard the picture rattles and punches in, 0 to 2; 1 is the default.
uniform float uShake;
uniform float uPunch;

// How far the ring splits the colours, 0 to 2; 1 is the default.
uniform float uFringe;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  vec2 c = vec2(uCenter.x, 1.0 - uCenter.y) * uSize;
  vec2 m = uSize * 0.5;
  float s = min(uSize.x, uSize.y);
  vec2 d = p - c;
  float r = length(d);
  vec2 dir = d / max(r, 0.001);
  float wave = 1.0 - step(0.5, uStyle);
  float edge = min(min(p.x, uSize.x - p.x), min(p.y, uSize.y - p.y));
  float keep = smoothstep(0.0, 0.08 * s, edge);

  float t = min(uAge / 0.5, 1.0);
  float spread = 1.0 - (1.0 - t) * (1.0 - t);
  float w = s * (0.07 + 0.1 * spread);
  float x = (r - 1.6 * uReach * length(max(c, uSize - c)) * spread) / w;
  float band = max(1.0 - x * x, 0.0);
  band = band * band;
  float ring = uIntensity * (1.0 - t) * wave * keep;
  vec2 q = p - dir * (0.9 * w * ring * x * band);

  float v = min(uAge / 0.4, 1.0);
  float spring = (1.0 - v) * (1.0 - v) * cos(12.566 * v);
  float nr = r / (0.5 * s * uReach);
  float cone = max(1.0 - nr * nr, 0.0);
  q = c + (q - c) * (1.0 - 0.45 * uIntensity * (1.0 - wave) * spring * cone * cone * keep);

  float rattle = max(1.0 - uAge / 0.4, 0.0);
  rattle = rattle * rattle * rattle;
  float punch = max(1.0 - uAge / 0.3, 0.0);
  punch = punch * punch;
  float jolt = mix(0.007, 0.015, wave) * uIntensity * uShake * rattle;
  float zoom = 1.0 + 2.2 * jolt + 0.08 * uIntensity * uPunch * wave * punch;
  vec2 shake = jolt * s * vec2(sin(81.681 * uAge + 0.6), sin(106.814 * uAge + 2.1));
  q = m + (q - m) / zoom + shake;
  vec2 fringe = dir * (0.02 * s * uFringe * ring * band) / zoom;

  vec3 color = vec3(tap(q + fringe).r, tap(q).g, tap(q - fringe).b);
  fragColor = vec4(clamp(color * (1.0 + 0.06 * ring * band), 0.0, 1.0), 1.0);
}
