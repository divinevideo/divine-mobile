# Light-mode visual audit

This pass checked the adaptive chrome in Home, Explore, Profile, search,
Inbox, notifications, library, Settings, dialogs, and sheets against the
light palette and the two reported screenshots. Fullscreen video, camera,
and editor chrome use fixed media colors and remain separate.

| Surface | Finding | Resolution |
| --- | --- | --- |
| Shared palette | Gray raised panels and mint utility fills compete with video and profile content. | Use a quieter warm neutral for raised panels and utility controls; keep green tint for selected controls. |
| Bottom navigation | Inactive glyphs were dark green at 32% opacity on white. | Use opaque muted ink in light mode; retain 32% opacity in dark mode. |
| Search and secondary actions | Pale fill and borders made interactive shapes hard to identify. | Add a visible light-mode search outline and strengthen light-mode button outlines. |
| Explore | A gray panel wrapped the tabs and video grid; the bright-green selected indicator was weak on white. | Put the grid on white and use dark green for the light-mode indicator. |
| Profile | The grid and badge outlines were too soft; tabs used the same low-contrast green indicator. | Put the grid on white and strengthen the badge outline and tab indicator. Keep the person's banner image or chosen color. |
| Inbox and notifications | Inbox uses the shared raised surface; notification tabs and retry links used fixed brand green on light surfaces. The pending-badge banner icon took the page background color on its brand-green circle, 2.08:1 in light. | Quiet the shared surface; use adaptive positive ink for those foregrounds. Give the banner icon on-primary ink, as filled primary buttons use: 8.49:1 in light. This is the pass's one dark-mode change, the icon moving from #000000 to #00150D (9.45:1 to 8.49:1 on the green). |
| Icons without a set color | The supporter chips on profiles, the account-recovery avatar, and a Developer Options caret drew the icon asset's own white fill, which disappears on light surfaces. | Give them primary-text ink, which resolves to the same white in dark mode. |
| Home, library, Settings, dialogs, sheets | Their main adaptive surfaces and body text already use semantic tokens. Remaining fixed whites and greens checked here belong to video, media illustration, filled actions, or status treatment. | Let the shared palette and control changes flow through these surfaces without replacing fixed media colors. |

Measured light-mode pairs after the changes: inactive nav icons on white
**5.24:1**; muted labels on the neutral control fill **4.53:1**; control
outline on that fill **3.04:1**; selected indicator on white **8.70:1**.
Text must clear 4.5:1 and meaningful icon or control boundaries 3:1.
