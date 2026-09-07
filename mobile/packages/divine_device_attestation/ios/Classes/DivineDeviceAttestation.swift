import CryptoKit
import DeviceCheck
import Foundation

/// App Attest wrapper that provisions one Secure Enclave key per key scope and
/// answers every later challenge with a local assertion.
///
/// `DCAppAttestService.generateKey` and `attestKey` are network round trips to
/// Apple's attestation servers and Apple rate limits them, so both run only on
/// the first challenge for a scope. The key identifier and attestation object
/// are cached in `UserDefaults` rather than the Keychain, which survives
/// uninstall: a wiped cache cannot strand a reinstall on a key that is already
/// gone. A restored device backup can still hand back an identifier without its
/// Secure Enclave key, since those keys never leave the device — that is what
/// the `DCError.invalidKey` re-provisioning path below exists for. Subsequent
/// challenges go through `generateAssertion`, which stays on device.
///
/// The scope is the account the proof will be published under, not the install.
/// Apple's App Attest guidance is against sharing one key among several users of
/// a device, and a per-account key adds no public linkability the event does not
/// already carry: it can only correlate videos that account already signed.
/// Every piece of cached state below therefore hangs off the scope, including
/// the queue of challenges waiting on an in-flight provisioning round — a flat
/// queue would hand one scope's credential to another scope's waiter.
@available(iOS 14.0, *)
final class DivineDeviceAttestation {
    /// A provisioned App Attest key plus the attestation object Apple issued
    /// for it. `isFresh` marks the credential Apple minted during this call —
    /// its attestation already binds the current challenge, so no separate
    /// assertion is needed.
    private struct Credential {
        let keyID: String
        let attestation: String
        let isFresh: Bool
    }

    /// An in-flight provisioning round and the challenges queued behind it.
    ///
    /// `id` is unique across scopes so a watchdog can only ever end the round
    /// it was armed for.
    private struct ProvisioningRound {
        let id: Int
        var waiting: [(Credential?) -> Void]
    }

    private enum StorageKey {
        static func keyID(_ scope: String) -> String { "AppAttestKeyIdentifier.\(scope)" }
        static func attestation(_ scope: String) -> String { "AppAttestAttestationObject.\(scope)" }
        static func pendingKeyID(_ scope: String) -> String { "AppAttestPendingKeyIdentifier.\(scope)" }
        static func pendingClientDataHash(_ scope: String) -> String { "AppAttestPendingClientDataHash.\(scope)" }
        static func pendingAttestAttempts(_ scope: String) -> String { "AppAttestPendingAttestAttempts.\(scope)" }
    }

    let inputString: String
    let keyScope: String
    var attestationString: String?
    var assertionString: String?

    private let attestService = DCAppAttestService.shared
    private var keyID: String?

    /// Guards the caches and the provisioning queues so concurrent challenges
    /// for one scope share a key instead of racing `generateKey` and burning
    /// Apple's rate limit. The state is static alongside it: the lock is shared,
    /// so everything it protects has to be.
    private static let defaults = UserDefaults.standard
    private static let lock = NSLock()
    private static var rounds: [String: ProvisioningRound] = [:]
    private static var nextRoundID = 0

    /// A generated-but-unattested key is retried once with its original client
    /// data hash, per Apple's guidance. If that retry still cannot produce an
    /// attestation, the slot is abandoned so one bad pending key cannot strand
    /// a scope permanently.
    private static let maxPendingAttestAttempts = 1

    /// How long a provisioning round may run before it is failed.
    ///
    /// `generateKey` and `attestKey` are network calls to Apple, and nothing
    /// here can cancel them. Without this, one wedged callback strands every
    /// later publish from that account behind its round until the app restarts
    /// — turning a single native hang into an account-wide publish stall.
    private static let provisioningTimeout: DispatchTimeInterval = .seconds(30)

    /// Native backstop for a generateAssertion callback that never returns.
    ///
    /// Dart gives the complete attestation call 10 seconds, so this deadline
    /// deliberately sits above that budget. It releases the pending assertion
    /// completion after Dart has already degraded the publish to no attestation
    /// without rejecting assertions inside Dart's success window. The deadline
    /// applies to each generateAssertion leg, not the complete native flow.
    private static let assertionTimeout: DispatchTimeInterval = .seconds(15)

    /// - Parameter keyScope: identifies whose key this is. An empty scope would
    ///   silently collapse every account back onto one shared key, so it is
    ///   rejected rather than defaulted.
    /// - Parameter challengeString: minted client-side at publish time, never
    ///   issued by a server. The current format is
    ///   `"<proofHash>:<pubkeyHex>"`; its UTF-8 bytes are hashed with SHA-256
    ///   before reaching Apple. The verifier contract and legacy cutover are
    ///   documented in `mobile/docs/NOSTR_VIDEO_EVENTS.md`.
    init?(challengeString: String, keyScope: String) {
        self.inputString = challengeString
        self.keyScope = keyScope

        guard !keyScope.isEmpty else {
            print("[!] Attest key scope missing")
            return nil
        }

        guard attestService.isSupported else {
            print("[!] Attest service not available")
            return nil
        }
    }

    func keyIdentifier() -> String {
        keyID ?? Self.defaults.string(forKey: StorageKey.keyID(keyScope)) ?? "Error in Key ID"
    }

    private var challengeHash: Data {
        Data(SHA256.hash(data: Data(inputString.utf8)))
    }

    func generateKeyAndAttest(completion: @escaping (Bool) -> Void) {
        resolveCredential(replacing: nil) { [weak self] credential in
            guard let self = self, let credential = credential else {
                completion(false)
                return
            }
            self.bind(credential, allowReprovision: true, completion: completion)
        }
    }

    /// Ties [credential] to the current challenge, re-provisioning once if the
    /// cached key turns out to be dead.
    private func bind(
        _ credential: Credential,
        allowReprovision: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        keyID = credential.keyID
        attestationString = credential.attestation

        if credential.isFresh {
            completion(true)
            return
        }

        makeAssertion(keyID: credential.keyID) { [weak self] assertion, errorCode in
            guard let self = self else {
                completion(false)
                return
            }

            if let assertion = assertion {
                self.assertionString = assertion
                completion(true)
                return
            }

            // Anything but a dead key is a transient failure; re-provisioning
            // would only spend another rate-limited key generation.
            guard allowReprovision, errorCode == .invalidKey else {
                completion(false)
                return
            }

            print("App Attest key no longer valid, re-provisioning")
            self.resolveCredential(replacing: credential.keyID) { refreshed in
                guard let refreshed = refreshed else {
                    completion(false)
                    return
                }
                self.bind(refreshed, allowReprovision: false, completion: completion)
            }
        }
    }

    private func makeAssertion(
        keyID: String,
        completion: @escaping (String?, DCError.Code?) -> Void
    ) {
        // Whichever side wins the race takes and clears the completion. Apple's
        // callback and the queued watchdog therefore retain only this shared
        // box after settlement, not the FlutterResult chain behind completion.
        let assertionLock = NSLock()
        var pendingCompletion: ((String?, DCError.Code?) -> Void)? = completion

        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + Self.assertionTimeout
        ) {
            assertionLock.lock()
            guard let completion = pendingCompletion else {
                assertionLock.unlock()
                return
            }
            pendingCompletion = nil
            assertionLock.unlock()

            print("App Attest assertion generation timed out")
            completion(nil, nil)
        }

        attestService.generateAssertion(keyID, clientDataHash: challengeHash) { assertion, error in
            assertionLock.lock()
            guard let completion = pendingCompletion else {
                assertionLock.unlock()
                return
            }
            pendingCompletion = nil
            assertionLock.unlock()

            if let error = error {
                print("Assertion error: \(error.localizedDescription)")
                completion(nil, (error as? DCError)?.code)
                return
            }

            guard let assertion = assertion else {
                print("No assertion object received")
                completion(nil, nil)
                return
            }

            completion(assertion.base64EncodedString(), nil)
        }
    }

    /// Hands back the scope's credential, provisioning one if its cache is
    /// empty. Pass the key that just failed as [staleKeyID] to replace it.
    private func resolveCredential(
        replacing staleKeyID: String?,
        completion: @escaping (Credential?) -> Void
    ) {
        let scope = keyScope
        Self.lock.lock()

        // Clear only while the cache still points at the key that failed. Two
        // assertions can fail on the same dead key, and dropping the
        // replacement the first recovery already stored would spend another
        // rate-limited key generation for nothing.
        if let staleKeyID = staleKeyID,
           Self.defaults.string(forKey: StorageKey.keyID(scope)) == staleKeyID {
            Self.defaults.removeObject(forKey: StorageKey.keyID(scope))
            Self.defaults.removeObject(forKey: StorageKey.attestation(scope))
        }

        if let keyID = Self.defaults.string(forKey: StorageKey.keyID(scope)),
           let attestation = Self.defaults.string(forKey: StorageKey.attestation(scope)) {
            Self.lock.unlock()
            completion(Credential(keyID: keyID, attestation: attestation, isFresh: false))
            return
        }

        if Self.rounds[scope] != nil {
            Self.rounds[scope]?.waiting.append(completion)
            Self.lock.unlock()
            return
        }

        let roundID = Self.nextRoundID
        Self.nextRoundID &+= 1
        Self.rounds[scope] = ProvisioningRound(id: roundID, waiting: [completion])
        Self.lock.unlock()

        Self.startProvisioningWatchdog(scope: scope, round: roundID)
        provision { credential in
            Self.finishProvisioning(with: credential, scope: scope, round: roundID)
        }
    }

    /// Fails [round] if it is still running once [provisioningTimeout] elapses.
    private static func startProvisioningWatchdog(scope: String, round: Int) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + provisioningTimeout
        ) {
            finishProvisioning(with: nil, scope: scope, round: round, timedOut: true)
        }
    }

    /// Provisions the scope's credential, resuming a key an earlier round
    /// generated but could not attest.
    ///
    /// Apple rate limits `generateKey`, so the identifier is recorded before
    /// `attestKey` runs and only dropped once the key is either attested or
    /// rejected outright. A throttled or offline `attestKey` therefore leaves a
    /// resumable key behind rather than burning a second generation on the next
    /// proof, which is what Apple's guidance to retry attestation with the same
    /// key and client data hash amounts to here.
    private func provision(completion: @escaping (Credential?) -> Void) {
        guard let pending = Self.pendingKey(scope: keyScope) else {
            generateAndAttest(completion: completion)
            return
        }

        guard pending.attestAttempts < Self.maxPendingAttestAttempts else {
            Self.clearPendingKey(scope: keyScope)
            generateAndAttest(completion: completion)
            return
        }

        Self.incrementPendingAttestAttempts(scope: keyScope)
        attest(keyID: pending.keyID, clientDataHash: pending.clientDataHash) { credential, keyIsDead in
            // A resumed key Apple no longer recognises — a device restore
            // between the two calls — can never be attested. Start over
            // instead of leaving this proof unattested for nothing.
            guard keyIsDead else {
                completion(credential)
                return
            }
            self.generateAndAttest(completion: completion)
        }
    }

    private func generateAndAttest(completion: @escaping (Credential?) -> Void) {
        // Captured strongly on purpose: a provisioning round must reach
        // `finishProvisioning` to release the queued challenges, even if the
        // instance that started it is already gone.
        attestService.generateKey { keyIdentifier, error in
            if let error = error {
                print("Key generation error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let keyIdentifier = keyIdentifier else {
                print("Failed to generate key identifier")
                completion(nil)
                return
            }

            let clientDataHash = self.challengeHash
            Self.storePendingKey(scope: self.keyScope, keyID: keyIdentifier, clientDataHash: clientDataHash)

            self.attest(keyID: keyIdentifier, clientDataHash: clientDataHash) { credential, _ in
                completion(credential)
            }
        }
    }

    /// Attests [keyID] against the [clientDataHash] it was generated for.
    ///
    /// [clientDataHash] predates the current challenge whenever a previous
    /// round generated the key but failed to attest it: Apple attests a key
    /// once, for the request it accepted, so a retry has to repeat the original
    /// inputs. The attestation that comes back then binds that earlier proof,
    /// which is why only a hash matching the current challenge yields a fresh
    /// credential — anything else has to sign its own assertion.
    ///
    /// The completion's second value reports a key Apple rejected as dead,
    /// which no later retry can revive.
    private func attest(
        keyID: String,
        clientDataHash: Data,
        completion: @escaping (Credential?, Bool) -> Void
    ) {
        attestService.attestKey(keyID, clientDataHash: clientDataHash) { attestation, error in
            if let error = error {
                print("Attestation error: \(error.localizedDescription)")

                let keyIsDead = (error as? DCError)?.code == .invalidKey
                if keyIsDead {
                    Self.clearPendingKey(scope: self.keyScope)
                }
                completion(nil, keyIsDead)
                return
            }

            guard let attestation = attestation else {
                print("No attestation object received")
                completion(nil, false)
                return
            }

            completion(
                Credential(
                    keyID: keyID,
                    attestation: attestation.base64EncodedString(),
                    isFresh: clientDataHash == self.challengeHash
                ),
                false
            )
        }
    }

    // A scope's pending slot is only touched inside its own provisioning round,
    // and `rounds` admits one of those per scope at a time, so these need no
    // lock of their own. The watchdog can still make a pending key stale: a
    // timed-out `attestKey` may later succeed, leaving behind a key that Apple
    // has already attested but the app deliberately did not cache. Bounded
    // retries below keep that stale slot from surviving forever.
    private static func pendingKey(scope: String) -> (keyID: String, clientDataHash: Data, attestAttempts: Int)? {
        guard let keyID = defaults.string(forKey: StorageKey.pendingKeyID(scope)),
              let clientDataHash = defaults.data(forKey: StorageKey.pendingClientDataHash(scope)) else {
            return nil
        }
        return (
            keyID,
            clientDataHash,
            defaults.integer(forKey: StorageKey.pendingAttestAttempts(scope))
        )
    }

    private static func storePendingKey(scope: String, keyID: String, clientDataHash: Data) {
        defaults.set(keyID, forKey: StorageKey.pendingKeyID(scope))
        defaults.set(clientDataHash, forKey: StorageKey.pendingClientDataHash(scope))
        defaults.set(0, forKey: StorageKey.pendingAttestAttempts(scope))
    }

    private static func incrementPendingAttestAttempts(scope: String) {
        let attemptsKey = StorageKey.pendingAttestAttempts(scope)
        defaults.set(defaults.integer(forKey: attemptsKey) + 1, forKey: attemptsKey)
    }

    private static func clearPendingKey(scope: String) {
        defaults.removeObject(forKey: StorageKey.pendingKeyID(scope))
        defaults.removeObject(forKey: StorageKey.pendingClientDataHash(scope))
        defaults.removeObject(forKey: StorageKey.pendingAttestAttempts(scope))
    }

    /// Ends [round] for [scope], storing [credential] and releasing everyone
    /// queued behind it.
    ///
    /// Runs at most once per round: the real callback and the watchdog race,
    /// and the loser returns without touching the queue. A late real
    /// credential is therefore dropped rather than stored. A generated key may
    /// remain in the pending slot for one later retry, but that retry is bounded
    /// so a late callback cannot make a scope reuse a doomed pending key forever.
    private static func finishProvisioning(
        with credential: Credential?,
        scope: String,
        round: Int,
        timedOut: Bool = false
    ) {
        lock.lock()

        guard let active = rounds[scope], active.id == round else {
            lock.unlock()
            return
        }
        rounds[scope] = nil

        if let credential = credential {
            defaults.set(credential.keyID, forKey: StorageKey.keyID(scope))
            defaults.set(credential.attestation, forKey: StorageKey.attestation(scope))
            clearPendingKey(scope: scope)
        }

        let waiting = active.waiting
        lock.unlock()

        if timedOut {
            print("App Attest provisioning timed out, failing \(waiting.count) queued challenge(s)")
        }

        // Only the caller that triggered provisioning gets the fresh-attestation
        // shortcut, and only when Apple bound the attestation to that caller's
        // challenge — a resumed key carries the hash of the proof that
        // generated it. Everyone else must sign themselves with an assertion.
        for (index, callback) in waiting.enumerated() {
            guard let credential = credential else {
                callback(nil)
                continue
            }
            callback(
                Credential(
                    keyID: credential.keyID,
                    attestation: credential.attestation,
                    isFresh: index == 0 && credential.isFresh
                )
            )
        }
    }
}
