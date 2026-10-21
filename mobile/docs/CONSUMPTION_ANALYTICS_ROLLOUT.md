# Consumption analytics release gate

`engagement_recorded` and `feed_depth_recorded` are disabled by default in every environment, including staging. `PRODUCT_ANALYTICS_ENABLED` does not enable them. A build must also set `CONSUMPTION_ANALYTICS_ENABLED=true`; the shared initialization, consent and signed-identity gates still apply. Existing playback and impression events keep their existing release behavior.

Do not enable the consumption switch until all of these are recorded:

- The canonical contract in divinevideo/divine-context#178 has landed with the source and generated commits preserved, and the vendored pins still resolve to that history. If its contract changes, regenerate and update both consumer repositories before enabling either event.
- divinevideo/divine-funnelcake#1359 has completed Platform and independent production/performance review, its schema/server have deployed, and production acceptance of both events is verified. An unsupported consumption event rejects its entire batch, including existing playback/impression rows.
- The named owners have recorded the consent/default policy, including its application to minors, and the release/metric decisions in the canonical human-decision record. The identity-boundary owner must explicitly settle video context on public actions: a video id resolves to its author, and public reactions/comments can be matched by video and timestamp to link a pseudonymous subject to an account.

Current client semantics count distinct deliberately reached videos, with the starting item included in the count. The first emitted depth is two; sessions without deliberate navigation emit no depth event and cannot provide a complete session denominator. The required surface distinguishes home (`feed`) from Explore (`discovery`) when their normalized feed types match. Swipes, explicit Skip taps and feed-tuning advances count. Automatic advance/recovery and same-page item replacement do not. Session, identity and consent boundaries restart from the last active item; source/list/reload changes restart from the newly selected item. Pagination and silent refresh keep the session.

Engagement rows include video context where available and never include raw creator/relationship-target pubkeys. Non-video follows omit video context. This field restriction is not a claim that the rows are unlinkable. Pre-login consumption is dropped and is never joined later. Keeping the release switch off is not consent or legal approval.
