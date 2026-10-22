// The fisheye effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `FisheyeVideoEffect` on
// Android, iOS and macOS. This is the same mapping: Core Image's
// CIBumpDistortion around the centre, with the radius at half the diagonal.
// Every pixel samples the picture closer to the centre,
//
//   source = centre + offset * (1 - scale * (1 - smoothstep(0, 1, t)))
//
// where t is the pixel's distance from the centre over the radius.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// CIBumpDistortion's scale: 0 leaves the picture as it is.
uniform float uScale;

uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 center = uSize * 0.5;
  vec2 offset = FlutterFragCoord().xy - center;
  float t = length(offset) / length(center);
  float pull = 1.0 - uScale * (1.0 - smoothstep(0.0, 1.0, t));
  fragColor = texture(uTexture, (center + offset * pull) / uSize);
}
