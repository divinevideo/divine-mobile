/// Explicit test-build entry. Production discovery stays disabled until the
/// backend coverage contract, hosting and cross-client acceptance are shipped.
const challengesTestEnabled = bool.fromEnvironment('DIVINE_CHALLENGES_TEST');
