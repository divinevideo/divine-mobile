// The spotlight effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `SpotlightVideoEffect` on
// Android, iOS and macOS. This is the same shader: the picture is dimmed, and
// two soft stage lights, one warm and one cool, wander slowly over it and
// light it back up.
//
// Distances are in pixels with y up, from the bottom left, as natively;
// Flutter counts y down, so it is flipped on the way in. `l` is the longer
// side.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// How dark the picture is outside the lights, 0 to 1.
uniform float uIntensity;

// Seconds since the effect started.
uniform float uTime;

uniform sampler2D uTexture;

out vec4 fragColor;

vec3 tap(vec2 q) {
  q = clamp(q, vec2(0.5), uSize - 0.5);
  return texture(uTexture, vec2(q.x, uSize.y - q.y) / uSize).rgb;
}

// A round light with a flat top and a short, soft edge.
float spot(vec2 p, vec2 centre, float reach) {
  vec2 d = (p - centre) / reach;
  float r2 = dot(d, d);
  return exp(-r2 * r2 * r2);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 p = vec2(fragCoord.x, uSize.y - fragCoord.y);
  float l = max(uSize.x, uSize.y);
  float t = uTime;
  vec2 warmCentre = uSize * vec2(0.5 + 0.28 * sin(0.41 * t + 0.3), 0.56 + 0.2 * sin(0.53 * t + 1.7));
  vec2 coolCentre = uSize * vec2(0.5 + 0.3 * sin(0.33 * t + 3.4), 0.44 + 0.22 * sin(0.47 * t + 0.6));
  vec3 light = max(
    vec3(1.12, 1.04, 0.9) * spot(p, warmCentre, 0.2 * l),
    vec3(0.92, 0.98, 1.12) * spot(p, coolCentre, 0.17 * l));
  float dark = 0.8 * uIntensity;
  vec3 base = tap(p);
  fragColor = vec4(clamp(base * (1.0 - dark + dark * light), 0.0, 1.0), 1.0);
}
