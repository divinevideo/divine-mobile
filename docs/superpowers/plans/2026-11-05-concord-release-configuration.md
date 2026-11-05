# Concord release configuration

The approved public invitation is the build's opt-in to real Rooms. No additional
feature flag or device switch is required. Existing account/minor guards and
configured-error fail-closed behavior remain authoritative; an unconfigured build
keeps the existing explicit reviewer POC opt-in.

1. Add actual compile-define tests for BuildConfiguration, route eligibility,
   Messages visibility, stale internal preferences and configured catalog errors.
   Run unconfigured and synthetic configured builds; observe configured tests red.
2. Derive the existing concordChat default from CONCORD_INVITE_URL presence or the
   existing reviewer flag. Keep all other eligibility and membership checks.
3. Add optional private define merging to iOS/Android Shorebird release jobs.
   Preserve absence rather than inserting an empty key.
4. Authenticate original provenance before a patch decides whether to include the
   invitation. Old releases without the key ignore today's invitation; configured
   releases require it and retain exact fingerprint verification.
5. Test actual resolved Codemagic scripts, file mode/no-value logging, legacy patch
   shape, missing/changed invitation rejection and release/provenance wiring.
6. Run related Flutter/build configuration suites and guards. Commit focused
   changes locally atop the repaired history, then hand the frozen head to root.

Do not read or configure production values, dispatch builds, push, merge or deploy.
Do not bypass Shorebird native/asset/source/provenance guards.
