// The tunnel and the spiral tunnel on a still, for their tiles in the video
// editor's effects picker.
//
// The renderers draw the effects natively, with `TunnelVideoEffect` on
// Android, iOS and macOS. This is the same shader: the picture holds a
// smaller copy of itself in its middle, which holds another, and so on. The
// plain tunnel nests whole frames, each with a thin shadow along its edge;
// the spiral tunnel nests rings within half the shorter side and twists them.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `level` is how many
// times e the picture grows from one copy to the next, `f` how far a pixel
// lies into its copy, `edge` how many pixels the point it reads lies inside
// its copy's edge, and `s` the shorter side.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How large the copy is, 0 to 1.
uniform float uIntensity;

// How far the picture has zoomed into its copy, 0 to 1.
uniform float uPhase;

// 1 for the spiral tunnel, 0 for the plain one.
uniform float uSpiral;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  if (uIntensity <= 0.0) {
    fragColor = vec4(tap(p), 1.0);
    return;
  }
  vec2 c = uSize * 0.5;
  vec2 d = p - c;
  float s = min(uSize.x, uSize.y);
  float level = -log(0.15 + 0.4 * uIntensity);
  vec2 q;
  float edge;
  if (uSpiral > 0.5) {
    float big = 0.5 * s;
    float lr = log(max(length(d), 0.001) / big);
    float a = atan(d.y, d.x);
    float twist = level / 6.2832;
    float f = fract(-(lr + a * twist) / level + uPhase);
    float r = big * exp(-level * f);
    float b = a - lr * twist;
    q = c + r * vec2(cos(b), sin(b));
    edge = big - r;
  } else {
    float m = max(max(abs(d.x) / c.x, abs(d.y) / c.y), 0.0001);
    float f = fract(-log(m) / level + uPhase);
    q = c + d * (exp(-level * f) / m);
    vec2 e = c - abs(q - c);
    edge = min(e.x, e.y);
  }
  float shade = 1.0 - 0.35 * (1.0 - smoothstep(0.0, 0.012 * s, edge));
  fragColor = vec4(tap(q) * shade, 1.0);
}
