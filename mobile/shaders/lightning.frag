// The lightning effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `LightningVideoEffect` on
// Android, iOS and macOS. This is the same shader: the picture flashes
// blue-white with a zigzag bolt from the top edge.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `l` is the longer
// side. The bolt's corners are `c0` at the top to `c8` where it ends, each
// `rise` lower than the one before, and its branch forks off `c3` through
// `b1` to `b3`, level with `c6`.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How bright the flash and the bolt are, then where the bolt enters the top
// and where it ends, in shares of the width and height.
uniform vec4 uStrike;

// The across positions of the bolt's corners, as shares of the width: the
// first four, then the last four.
uniform vec4 uPathA;
uniform vec4 uPathB;

// The across positions of the branch's three corners, and 1 when the bolt
// has a branch.
uniform vec4 uBranch;

// The colour the flash lights the picture with, and that of the glow around
// the bolt.
uniform vec3 uTint;
uniform vec3 uGlow;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

float segment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  vec3 base = tap(p);
  float flash = uStrike.x;
  float bolt = uStrike.y;
  if (flash <= 0.0 && bolt <= 0.0) {
    fragColor = vec4(base, 1.0);
    return;
  }
  float l = max(uSize.x, uSize.y);
  float top = uSize.y + 0.02 * l;
  float rise = (top - uStrike.w * uSize.y) / 8.0;
  vec2 c0 = vec2(uStrike.z * uSize.x, top);
  vec2 c1 = vec2(uPathA.x * uSize.x, top - rise);
  vec2 c2 = vec2(uPathA.y * uSize.x, top - 2.0 * rise);
  vec2 c3 = vec2(uPathA.z * uSize.x, top - 3.0 * rise);
  vec2 c4 = vec2(uPathA.w * uSize.x, top - 4.0 * rise);
  vec2 c5 = vec2(uPathB.x * uSize.x, top - 5.0 * rise);
  vec2 c6 = vec2(uPathB.y * uSize.x, top - 6.0 * rise);
  vec2 c7 = vec2(uPathB.z * uSize.x, top - 7.0 * rise);
  vec2 c8 = vec2(uPathB.w * uSize.x, top - 8.0 * rise);
  vec2 b1 = vec2(uBranch.x * uSize.x, top - 4.0 * rise);
  vec2 b2 = vec2(uBranch.y * uSize.x, top - 5.0 * rise);
  vec2 b3 = vec2(uBranch.z * uSize.x, top - 6.0 * rise);
  float upper = min(min(segment(p, c0, c1), segment(p, c1, c2)), min(segment(p, c2, c3), segment(p, c3, c4)));
  float lower = min(min(segment(p, c4, c5), segment(p, c5, c6)), min(segment(p, c6, c7), segment(p, c7, c8)));
  float trunk = min(upper, lower);
  float side = min(min(segment(p, c3, b1), segment(p, b1, b2)), segment(p, b2, b3));
  float w = 0.003 * l;
  float trunkEnd = clamp((p.y - c8.y) / (2.0 * rise), 0.0, 1.0);
  float sideEnd = clamp((p.y - b3.y) / (2.0 * rise), 0.0, 1.0);
  float core = (0.3 + 0.7 * trunkEnd) * exp(-trunk * trunk / (w * w)) + 0.7 * uBranch.w * sideEnd * exp(-side * side / (0.36 * w * w));
  float glow = (0.3 + 0.7 * trunkEnd) * exp(-trunk / (0.035 * l)) + 0.5 * uBranch.w * sideEnd * exp(-side / (0.025 * l));
  vec3 tint = uTint;
  vec3 lit = base * (1.0 + 0.9 * flash * tint) + 0.22 * flash * tint;
  lit += bolt * (min(core, 1.0) * vec3(0.95, 0.97, 1.0) + 0.6 * glow * uGlow);
  fragColor = vec4(clamp(lit, 0.0, 1.0), 1.0);
}
