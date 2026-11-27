// The bricks effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `BricksVideoEffect` on
// Android, iOS and macOS. This is the same shader: the picture built from
// square toy bricks seen from above, each with a round stud.
//
// Each brick takes the mean colour of four taps inside it, a little more
// colourful and cut to five levels a channel, as a box of bricks holds a
// limited set of colours. Light comes from the top left: it catches the
// bricks' top and left edges and the studs' rims, the studs cast a short
// shadow to the bottom right, and dark seams run between the bricks. A
// little of the light is added rather than multiplied, so black bricks show
// their studs too.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side, `c` a brick's side in pixels, `d` the place within a brick from its
// middle, in bricks, and `aa` one pixel in bricks, which softens every edge.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the picture turns into bricks, 0 to 1.
uniform float uIntensity;

// How large the bricks are, as a share of the default.
uniform float uBrick;

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
  float s = min(uSize.x, uSize.y);
  float c = max(6.0, s / 28.0 * uBrick);
  vec2 cell = floor(p / c);
  vec2 middle = (cell + 0.5) * c;
  vec3 ink = 0.25 * (tap(middle + vec2(-0.25, -0.25) * c) + tap(middle + vec2(0.25, -0.25) * c) +
    tap(middle + vec2(-0.25, 0.25) * c) + tap(middle + vec2(0.25, 0.25) * c));
  vec3 brick = floor(clamp(mix(vec3(luma(ink)), ink, 1.2), 0.0, 1.0) * 4.0 + 0.5) / 4.0;
  vec2 d = p / c - cell - 0.5;
  float aa = 1.0 / c;
  vec2 toLight = vec2(-0.70710678, 0.70710678);
  float edge = 0.5 - max(abs(d.x), abs(d.y));
  float seam = smoothstep(0.0, 1.5 * aa, edge);
  vec2 outward = abs(d.x) > abs(d.y) ? vec2(sign(d.x), 0.0) : vec2(0.0, sign(d.y));
  float bevel = 1.0 + 0.3 * (1.0 - clamp(edge / 0.08, 0.0, 1.0)) * dot(outward, toLight);
  float r = length(d);
  float stud = 1.0 - smoothstep(0.3 - aa, 0.3 + aa, r);
  float shadow = 1.0 - smoothstep(0.3 - aa, 0.3 + aa, length(d - vec2(0.05, -0.05)));
  vec2 normal = d / max(r, 0.0001);
  float rim = 1.08 + 0.35 * smoothstep(0.22, 0.3, r) * dot(normal, toLight);
  float shade = mix(bevel * (1.0 - 0.25 * shadow), rim, stud);
  vec3 bricks = clamp((brick * shade + 0.12 * max(shade - 1.0, 0.0)) * (0.35 + 0.65 * seam), 0.0, 1.0);
  fragColor = vec4(mix(tap(p), bricks, uIntensity), 1.0);
}
