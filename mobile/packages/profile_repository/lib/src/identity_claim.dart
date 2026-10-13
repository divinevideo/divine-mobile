// ABOUTME: Re-exports verifier_client identity types so profile_repository
// ABOUTME: callers have one cohesive surface for NIP-39 claims.

export 'package:verifier_client/verifier_client.dart'
    show
        IdentityClaim,
        SignInConfirmException,
        SignInConfirmation,
        SignInRefusal,
        SignInSecrets,
        VerificationResult,
        VerifierApiException,
        VerifierClient,
        VerifierClientException,
        VerifierNetworkException,
        VerifierPlatform,
        VerifierTimeoutException;
