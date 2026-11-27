// The fisheye effect on a still, for its tile in the video editor's effects
// picker.
//
// The renderers draw the effect natively, with `FisheyeVideoEffect` on
// Android, iOS and macOS. This is the same mapping: Core Image's
// CIBumpDistortion around the centre, the frame's middle unless the settings
// move it, with the radius at half the diagonal times the size set. Every
// pixel samples the picture closer to the centre,
//
//   source = centre + offset * (1 - scale * (1 - smoothstep(0, 1, t)))
//
// where t is the pixel's distance from the centre over the radius.

#include <flutter/runtime_effect.glsl>

// Engine-set: the size of the bound texture. Must be the first uniform.
uniform vec2 uSize;

// CIBumpDistortion's scale: 0 leaves the picture as it is.
uniform float uScale;

// Where the bulge sits, as shares of the width from the left and of the
// height from the top.
uniform vec2 uCenter;

// The radius, as a share of half the diagonal.
uniform float uRadius;

uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 center = uCenter * uSize;
  vec2 offset = FlutterFragCoord().xy - center;
  float t = length(offset) / (uRadius * length(0.5 * uSize));
  float pull = 1.0 - uScale * (1.0 - smoothstep(0.0, 1.0, t));
  fragColor = texture(uTexture, (center + offset * pull) / uSize);
}
