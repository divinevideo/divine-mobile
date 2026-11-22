# Video-first badge discovery

Explore → Badges and badge detail follow the existing Lists gallery: a large
thumbnail area leads each card, followed by compact identity and supporting
text. Repeated Videos buttons do not belong in either surface.

Use `DivineListMedia.videos` for indexed clips. Tapping the fan starts its
leading clip with that exact event and author; the identity opens detail's
complete video grid. Keep badge artwork visible in the identity row.
When indexed clips are unavailable, use the original badge artwork at the
same 177:120 media ratio and open the badge detail directly. Do not invent a
video count or add per-card relay reconciliation to the indexed discovery path.

On detail, place the existing inline video grid immediately after badge
identity and owner actions. Follow controls, membership and issuer information
support the videos below them. Follow is a compact control; its public
subscription notice remains visible. Preserve reporting and owner actions.

A later incomplete holder reconciliation must keep an already loaded,
policy-filtered video preview visible. Retain the membership error and retry;
do not represent the preview as a complete holder set.

The alternative of replacing big Videos buttons with smaller Videos buttons
still makes watching a separate action and does not follow the Lists guide.
Building another thumbnail renderer duplicates the existing design and is
unnecessary. Reuse the current Flutter design components, adaptive colors,
localizations and visibility policy. No new protocol or backend work is needed
for this layout change.
