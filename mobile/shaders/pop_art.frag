// The pop art effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `PopArtVideoEffect` on
// Android, iOS and macOS. This is the same shader: the picture four times in
// a 2x2 grid, each copy screen-printed in three flat tones of its own bold
// colour scheme.
//
// Each copy is the whole picture at half size. Its brightness is cut into a
// dark, a middle and a light tone, with a narrow blend between them that
// keeps the edges from crawling as the picture moves, and each tone takes
// that copy's colour. The intensity mixes the copies' own colours into the
// print; the grid shows at any intensity above zero, so at zero the picture
// is left as it is.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. Copy 0 is at the
// bottom left, 1 at the bottom right, 2 at the top left and 3 at the top
// right.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the copies turn into the print, 0 to 1.
uniform float uIntensity;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

// The colour of copy `i` among `a`, `b`, `c` and `d`.
vec3 pick(float i, vec3 a, vec3 b, vec3 c, vec3 d) {
  return mix(mix(a, b, step(0.5, i)), mix(c, d, step(2.5, i)), step(1.5, i));
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  vec2 halfSize = 0.5 * uSize;
  vec2 quadrant = step(halfSize, p);
  vec2 local = mix(p, (p - halfSize * quadrant) * 2.0, step(0.0001, uIntensity));
  vec3 copy = tap(local);
  float l = luma(copy);
  float level = smoothstep(0.28, 0.32, l) + smoothstep(0.58, 0.62, l);
  float i = quadrant.x + 2.0 * quadrant.y;
  vec3 dark = pick(i, vec3(0.1, 0.1, 0.35), vec3(0.3, 0.05, 0.4), vec3(0.55, 0.0, 0.1),
    vec3(0.0, 0.25, 0.3));
  vec3 mid = pick(i, vec3(1.0, 0.2, 0.6), vec3(1.0, 0.5, 0.1), vec3(0.45, 0.85, 0.2),
    vec3(1.0, 0.85, 0.0));
  vec3 light = pick(i, vec3(1.0, 0.9, 0.2), vec3(0.3, 0.9, 1.0), vec3(1.0, 0.75, 0.85),
    vec3(0.8, 0.7, 1.0));
  vec3 print = mix(mix(dark, mid, clamp(level, 0.0, 1.0)), light, clamp(level - 1.0, 0.0, 1.0));
  fragColor = vec4(mix(copy, print, uIntensity), 1.0);
}
