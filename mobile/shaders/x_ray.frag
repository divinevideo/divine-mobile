// The X-ray effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `XRayVideoEffect` on
// Android, iOS and macOS. This is the same shader: the picture as an X-ray
// film, its brightness turned around into cold blue-white on near black,
// with the outlines standing out like bone.
//
// What was dark turns bright and what was bright fades out. The outlines,
// found where the brightness changes sharply with a Sobel filter, are
// lightened on top, so shapes keep their edges.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `s` is the shorter
// side, `e` the Sobel filter's step in pixels.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How far the picture turns into the X-ray, 0 to 1.
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

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float s = min(uSize.x, uSize.y);
  float e = max(1.0, s / 540.0);
  vec3 color = tap(p);
  float tl = luma(tap(p + vec2(-e, e)));
  float tc = luma(tap(p + vec2(0.0, e)));
  float tr = luma(tap(p + vec2(e, e)));
  float ml = luma(tap(p + vec2(-e, 0.0)));
  float mr = luma(tap(p + vec2(e, 0.0)));
  float bl = luma(tap(p + vec2(-e, -e)));
  float bc = luma(tap(p + vec2(0.0, -e)));
  float br = luma(tap(p + vec2(e, -e)));
  float gx = tr + 2.0 * mr + br - tl - 2.0 * ml - bl;
  float gy = tl + 2.0 * tc + tr - bl - 2.0 * bc - br;
  float bone = smoothstep(0.1, 0.6, length(vec2(gx, gy)));
  float density = clamp(1.1 * pow(max(1.0 - luma(color), 0.0), 1.6) + 0.5 * bone, 0.0, 1.0);
  vec3 film = mix(vec3(0.0, 0.02, 0.06), vec3(0.78, 0.9, 1.0), density);
  fragColor = vec4(mix(color, film, uIntensity), 1.0);
}
