# Chat mentions

Typing @ in a public test room offers the existing account picker, prioritizing room participants and followed accounts. A selection publishes an explicit account mention inside the authenticated encrypted rumor, using a p tag and a nostr:npub reference. Display names alone never identify recipients. Received references use the existing rich text renderer.

Notifications are in-app, not background OS pushes: the push service cannot read the encrypted chat payload. The existing internal chat flag and protected-minor gates remain in place. This work does not enable live spaces or livestreams.

Default eligibility: only people the recipient follows, only rooms the recipient has opened, only explicit mentions of their key. Block/mute policy applies and updates remove ineligible rows. Self mentions do not notify. Group into one row per sender and room, retain at most 50 rows, and exclude history from before the first room visit and implausible future timestamps. Read state is account scoped and durable. Notifications reopen the room; encrypted message content is never copied to a public notification service.

Alternatives considered: all room participants (membership is not verified in this POC); all mentions with a rate limit (still allows strangers to create unwanted alerts); followed senders (chosen as a conservative default under the user's instruction to determine spam protections). No extra confirmation workflow is introduced.
