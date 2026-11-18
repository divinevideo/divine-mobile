# Library reactions and Classic selection

Rabble approved a library preview action, **Record reaction**, with the original on the left and the new camera take on the right. Recording uses the existing camera. The existing layout screen previews both clips and lets the user change framing or choose picture-in-picture before Done opens the editor. Cancel leaves the saved source untouched; the unfinished session is preserved before replacing it.

Approaches: reuse the split-screen builder (chosen: keeps its framing, render and attribution pipeline); a separate reaction editor would duplicate these responsibilities. Sequential insertion was offered and Rabble chose side by side.

Fix the reported square-Classic/vertical-project selection restriction using the existing crop guide, and normalize imported clip metadata to the composition shape without mutating the saved library original. Keep attribution and camera provenance. Flutter 3.47.9, existing BLoC and adaptive Divine UI only.
