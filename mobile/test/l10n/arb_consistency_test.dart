// ABOUTME: Tests that ARB locale files stay in sync with the English template.
// ABOUTME: Prevents generated l10n APIs from drifting from translated files.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('ARB consistency', () {
    test('all locales define the same message keys as app_en.arb', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));
      final templateKeys = _messageKeys(template);

      for (final file in arbFiles) {
        final arb = _readArb(file);
        final keys = _messageKeys(arb);

        expect(
          keys.difference(templateKeys),
          isEmpty,
          reason: '${file.path} has keys missing from app_en.arb',
        );
        expect(
          templateKeys.difference(keys).difference(_knownUntranslatedDebt),
          isEmpty,
          reason: '${file.path} is missing keys from app_en.arb',
        );
      }
    });

    test('known untranslated debt only names template messages', () {
      final template = _readArb(File('lib/l10n/app_en.arb'));

      expect(
        _knownUntranslatedDebt.difference(_messageKeys(template)),
        isEmpty,
        reason: 'stale untranslated-debt entries must be removed',
      );
    });

    test('owner delete copy keeps Divine and Nostr disclosure', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      const keys = [
        'shareMenuDeleteConfirmation',
        'videoGridDeleteVideoSubtitle',
      ];

      for (final file in arbFiles) {
        final arb = _readArb(file);

        for (final key in keys) {
          final value = arb[key];

          expect(
            value,
            isA<String>().having((s) => s.isNotEmpty, 'isNotEmpty', isTrue),
            reason: '${file.path} must define $key',
          );
          expect(
            value,
            allOf(contains('Divine'), contains('Nostr')),
            reason:
                '${file.path} $key must preserve both the Divine deletion and '
                'third-party Nostr visibility disclosure',
          );
        }
      }
    });

    test('Keycast key export copy is localized for every locale', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));
      const keys = [
        'keyManagementKeycastRemoteSigning',
        'keyManagementKeycastPasswordPrompt',
        'keyManagementKeycastCopyKey',
        'keyManagementKeycastCopyBlocked',
        'keyManagementKeycastWrongPassword',
        'keyManagementKeycastTooManyAttempts',
        'keyManagementKeycastRateLimited',
        'keyManagementKeycastSignInAgain',
        'keyManagementKeycastEmailUnverified',
        'keyManagementKeycastDenied',
        'keyManagementKeycastNoKey',
        'keyManagementKeycastGenericFailure',
      ];

      for (final file in arbFiles) {
        final arb = _readArb(file);

        for (final key in keys) {
          expect(
            arb[key],
            isNot(template[key]),
            reason: '${file.path} must not fall back to English for $key',
          );
        }
      }
    });

    test('Nostr signature verification copy is localized for every locale', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));

      for (final file in arbFiles) {
        final arb = _readArb(file);

        for (final key in _signatureVerificationKeys) {
          final value = arb[key];

          expect(
            value,
            isA<String>().having((s) => s.isNotEmpty, 'isNotEmpty', isTrue),
            reason: '${file.path} must define a non-empty $key message',
          );
          expect(
            value,
            isNot(template[key]),
            reason:
                '${file.path} must not fall back to English for Nostr '
                'signature verification copy',
          );
        }
      }
    });

    test('CSAM report reason does not collapse into child safety copy', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      for (final file in arbFiles) {
        final arb = _readArb(file);

        expect(
          arb['reportReasonCsam'],
          isNot(arb['reportReasonChildSafety']),
          reason:
              '${file.path} must keep CSAM distinct from child safety in the '
              'report reason title',
        );
        expect(
          arb['reportReasonCsamSubtitle'],
          isNot(arb['reportReasonChildSafetySubtitle']),
          reason:
              '${file.path} must keep CSAM distinct from child safety in the '
              'report reason subtitle',
        );
      }
    });

    test('age-gate signer-unreachable copy is localized for every locale', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));
      final source = template['videoErrorVerifyAgeSignerUnreachable'];

      for (final file in arbFiles) {
        final arb = _readArb(file);
        final value = arb['videoErrorVerifyAgeSignerUnreachable'];

        expect(
          value,
          isA<String>().having((s) => s.isNotEmpty, 'isNotEmpty', isTrue),
          reason:
              '${file.path} must define a non-empty signer-unreachable '
              'message',
        );
        expect(
          value,
          isNot(source),
          reason:
              '${file.path} must not fall back to English for the age-gate '
              'signer-unreachable message',
        );
        // The whole point of this key is a distinct remedy from the generic
        // verify-failed copy; a translation that collapses to that copy
        // silently defeats it.
        expect(
          value,
          isNot(arb['videoErrorVerifyAgeFailed']),
          reason:
              '${file.path} signer-unreachable copy must differ from its '
              'generic videoErrorVerifyAgeFailed copy',
        );
      }
    });

    test('default-relay removal copy is localized for every locale', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));
      const keys = [
        'relaySettingsRemoveDefaultRelayTitle',
        'relaySettingsRemoveDefaultRelayMessage',
        'relaySettingsRemoveRelayTooltip',
      ];
      const mustDifferFromEnglish = {
        'relaySettingsRemoveDefaultRelayTitle',
        'relaySettingsRemoveDefaultRelayMessage',
        'relaySettingsRemoveRelayTooltip',
      };

      for (final file in arbFiles) {
        final arb = _readArb(file);

        for (final key in keys) {
          final value = arb[key];

          expect(
            value,
            isA<String>().having((s) => s.isNotEmpty, 'isNotEmpty', isTrue),
            reason: '${file.path} must define a non-empty $key message',
          );
          if (mustDifferFromEnglish.contains(key)) {
            expect(
              value,
              isNot(template[key]),
              reason:
                  '${file.path} must not fall back to English for the '
                  'default-relay removal warning',
            );
          }
        }
      }
    });

    test('every locale keeps the placeholders app_en.arb interpolates', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));

      // Only placeholders whose value the English source actually substitutes.
      // A selector-only argument, such as the `count` in `{count, plural, ...}`,
      // interpolates nothing, so a language without that distinction may
      // legitimately render a bare noun instead.
      final interpolated = <String, Set<String>>{};
      for (final key in _messageKeys(template)) {
        final source = template[key];
        if (source is! String) continue;
        final used = _declaredPlaceholders(
          template,
          key,
        ).where((name) => _placeholderPattern(name).hasMatch(source)).toSet();
        if (used.isNotEmpty) interpolated[key] = used;
      }

      for (final file in arbFiles) {
        final arb = _readArb(file);

        for (final entry in interpolated.entries) {
          final value = arb[entry.key];
          if (value is! String) continue;

          for (final name in entry.value) {
            // gen-l10n takes the signature from the template, so a dropped
            // placeholder still compiles: the generated getter accepts the
            // argument and silently never renders it.
            expect(
              _placeholderPattern(name).hasMatch(value),
              isTrue,
              reason:
                  '${file.path} drops {$name} from ${entry.key}, so its value '
                  'would never reach the user',
            );
          }
        }
      }
    });

    test('chroma key surface guidance is localized for every locale', () {
      final arbFiles =
          Directory('lib/l10n')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));
      const keys = [
        'videoEditorChromaKeySurfaceHint',
        'videoEditorChromaKeyDetectFailed',
      ];

      for (final file in arbFiles) {
        final arb = _readArb(file);
        for (final key in keys) {
          expect(
            arb[key],
            isA<String>().having((s) => s.isNotEmpty, 'isNotEmpty', isTrue),
            reason: '${file.path} must define a non-empty $key message',
          );
          expect(
            arb[key],
            isNot(template[key]),
            reason:
                '${file.path} must not fall back to English for the chroma '
                'key surface guidance',
          );
        }
      }
    });

    test('chroma key copy names a wall, the frame, and the manual way out', () {
      final template = _readArb(File('lib/l10n/app_en.arb'));
      final hint = (template['videoEditorChromaKeySurfaceHint']! as String)
          .toLowerCase();
      final failure = (template['videoEditorChromaKeyDetectFailed']! as String)
          .toLowerCase();

      // Epic #8543 ratified the reframing: the requirement is not a green
      // sheet, it is any uniform surface the subject is not wearing, and most
      // people already own one. These three facts are what turn the feature's
      // biggest bounce point into its onboarding (#8546, #8547) — losing any
      // of them to a copy tweak puts the dead end back.
      expect(hint, contains('wall'));
      expect(hint, contains('frame'));

      expect(failure, contains('wall'));
      expect(failure, contains('frame'));
      expect(
        failure,
        contains('by hand'),
        reason:
            'The failure has to end on something the user can do right now, '
            'not on what went wrong.',
      );
    });

    test('Bluesky backfill disclosure is localized for every locale', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));
      const keys = [
        'blueskyBackfillDisclosureTitle',
        'blueskyBackfillDisclosureSubtitle',
      ];

      for (final file in arbFiles) {
        final arb = _readArb(file);
        for (final key in keys) {
          expect(
            arb[key],
            isA<String>().having((s) => s.isNotEmpty, 'isNotEmpty', isTrue),
            reason: '${file.path} must define a non-empty $key message',
          );
          expect(
            arb[key],
            isNot(template[key]),
            reason:
                '${file.path} must not fall back to English for the Bluesky '
                'backfill disclosure',
          );
        }
      }
    });

    test('profile badge sheet copy is localized for every locale', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));

      for (final file in arbFiles) {
        final arb = _readArb(file);

        final profileBadgeSheetKeys = {
          ..._profileBadgeSheetKeys,
          if (!_profileBadgeFallbackSemanticLabelEnglishLocales.any(
            file.path.endsWith,
          ))
            'profileBadgeFallbackSemanticLabel',
        };

        for (final key in profileBadgeSheetKeys) {
          final value = arb[key];

          expect(
            value,
            isA<String>().having((s) => s.isNotEmpty, 'isNotEmpty', isTrue),
            reason: '${file.path} must define a non-empty $key message',
          );
          expect(
            value,
            isNot(template[key]),
            reason:
                '${file.path} must not fall back to English for the profile '
                'badge sheet copy',
          );
        }

        // The button opens the in-app editor now, so a translation that still
        // sends people to the website is stale rather than merely wordy.
        expect(
          arb['profileBadgeFooterLink'],
          isNot(contains('badges.divine.video')),
          reason:
              '${file.path} must not point profileBadgeFooterLink at '
              'badges.divine.video',
        );
      }
    });
  });
}

// Keys intentionally allowed to fall back to English until a translation pass.
// Keep this list small and reviewable so new translation gaps stay visible.
const _knownUntranslatedDebt = <String>{
  // Discord proof-rejection reasons (verifier PR #43). Each names a distinct
  // way a Discord proof can fail, replacing one message that blamed the npub
  // for all of them. Deferred to the next human pass rather than
  // machine-translated: verifyErrorDiscordAuthorMismatch turns on the
  // username/display-name distinction, which each locale has to render in
  // whatever words Discord itself uses there.
  'verifyErrorProofRejected',
  'verifyErrorProofMissingNpub',
  'verifyErrorDiscordDmLink',
  'verifyErrorDiscordChannelLink',
  'verifyErrorDiscordMessageNotFound',
  'verifyErrorDiscordBotNoAccess',
  'verifyErrorDiscordAuthorMismatch',
  'verifyErrorDiscordContentUnavailable',
  // Refused reaction-removal recovery (#8563). These mirror the existing
  // message-removal wording and need the same per-locale human verb choice.
  'dmReactionRemovalRefusedA11yLabel',
  'dmReactionRemovalRefusedTitle',
  'dmReactionRemovalRefusedDetails',
  // Retraction-in-flight screen-reader label (#8201). Deferred to the next
  // human translation pass rather than machine-translated: its translated
  // siblings dmDeleteRefusedMessage / dmDeleteRefusedDetails each chose a
  // per-locale verb for "delete for everyone", and this label has to match
  // whichever one that locale picked.
  'dmDeletePendingLabel',
  // Content-report image-rejection notice (#8210). The translated sibling
  // reportDetailsTextOnly already ships per locale; this reactive notice is
  // left in English until the same human translation pass picks it up, rather
  // than machine-translating moderation copy that has to say exactly what it
  // means.
  'reportDetailsImageNotAttached',
  // Support-form image-rejection notices (#8602). Deferred to the same human
  // translation pass as reportDetailsImageNotAttached so attachment guidance
  // stays accurate in every locale rather than being machine-translated.
  'bugReportImageInsertionRejected',
  'featureRequestImageInsertionRejected',
  // Deletion prep-failure copy (feature #6126). Deferred to the l10n
  // translation-debt pass (#7632) rather than machine-translating a
  // safety-critical "nothing was deleted" message. Mirror the translated
  // sibling deleteAccountDeletionIncomplete per locale when the pass runs.
  'deleteAccountDeletionNotStarted',
  // New Lists UX detail screen (#8198): hero header, follow pill, owner
  // actions sheet, and manage-posts mode. Deferred to the next human
  // translation pass; the list-follow verb needs per-locale judgment
  // (person-follow vs list-subscribe differ in several locales).
  // DM size-refusal copy (#7331). Deferred to the next human translation pass
  // alongside listPrivateFull: both name a size limit the user can act on, and
  // several locales want the same verb for "shorten" in each.
  'dmSendTooLongMessage',
  // Private-list size ceiling (#7331). Deferred to the next human translation
  // pass: "full" here means an encryption size limit rather than a item-count
  // limit, and several locales need a different noun for that distinction.
  'listPrivateFull',
  'listEditInfoAction',
  'listManageVideosAction',
  'listFollowButton',
  'listFollowingButton',
  'listRemoveVideosButton',
  'listRemoveVideosSuccess',
  'listRemoveVideosFailure',
  // Log-export copy (#8112 / #8113 / #8114). Left in English until a human
  // translation pass; machine-translating a diagnostic instruction the user
  // has to follow exactly is how it stops meaning what it says.
  'supportNoLogsToExport',
  'supportExportLogsUnconfirmed',
  // Clear-logs copy (#8114). New UI strings left in English until the same
  // human translation pass rather than machine-translated into 21 locales.
  'supportClearLogs',
  'supportClearLogsSubtitle',
  'supportClearLogsConfirmTitle',
  'supportClearLogsConfirmButton',
  'supportLogsCleared',
  // Account-enforcement translation remains tracked in #7765. The policy copy
  // is deliberately left in English until its human translation pass.
  'accountStatusTitle',
  'accountStatusAllClearHeading',
  'accountStatusTileSubtitleRestricted',
  'profileAccountRestricted',
  'publishErrorAccountRestricted',
  'uploadFailureSheetAccountStatusButton',
  'accountStatusSuspendedHeading',
  'accountStatusSuspendedBody',
  'accountStatusBannedHeading',
  'accountStatusBannedBody',
  'accountStatusRestrictedHeading',
  'accountStatusRestrictedBody',
  'accountStatusLastKnownBody',
  'accountStatusUnavailableHeading',
  'accountStatusUnavailableBody',
  'accountStatusSignedOutHeading',
  'accountStatusSignedOutBody',
  'accountStatusKeysUnaffectedHeading',
  'accountStatusKeysUnaffectedBody',
  'accountStatusAppealHeading',
  'accountStatusAppealBody',
  'accountStatusMoveAccount',
  'accountStatusRetry',
  // Restricted-minor age/deletion copy (#8238). This is load-bearing copy,
  // so non-English locales fall back to English until speaker review.
  'minorAccountReviewContentTitle',
  'minorAccountReviewContentBody',
  // Response clock copy (#8156). Load-bearing deadline guidance remains in
  // English until human translation review.
  'minorAccountReviewResponseClockRunningTitle',
  'minorAccountReviewResponseClockRunningDays',
  'minorAccountReviewResponseClockRunningHours',
  'minorAccountReviewResponseClockPausedTitle',
  'minorAccountReviewResponseClockPausedBody',
  'minorAccountReviewResponseClockExpiredTitle',
  'minorAccountReviewResponseClockExpiredBody',
  'minorAccountReviewResponseClockUnavailableTitle',
  'minorAccountReviewResponseClockUnavailableBody',
  'devOptionsMinorReviewResponseClockTitle',
  'devOptionsMinorReviewResponseClockRunning',
  'devOptionsMinorReviewResponseClockPaused',
  'devOptionsMinorReviewResponseClockExpired',
  'devOptionsMinorReviewResponseClockNotApplicable',
  'devOptionsMinorReviewResponseClockMalformed',
  'devOptionsMinorReviewResponseClockRunningToast',
  'devOptionsMinorReviewResponseClockPausedToast',
  'devOptionsMinorReviewResponseClockExpiredToast',
  'devOptionsMinorReviewResponseClockNotApplicableToast',
  'devOptionsMinorReviewResponseClockMalformedToast',
  // Restricted-minor appeal policy (#8239). This is load-bearing age and
  // moderation copy, so non-English locales fall back to English until
  // speaker review.
  'minorAccountReviewAppealTitle',
  'minorAccountReviewAppealTeenBody',
  'minorAccountReviewAppealUnder13Body',
  // Inbox Badges tab and its All-tab banner. Translation deferred to the next
  // l10n pass.
  'notificationsTabBadges',
  'notificationsPendingBadges',
  'notificationsBadgesEmpty',
  // Critical metadata-loss prevention copy added in #8014. Translation is
  // deferred to the next l10n pass.
  'shareMenuOriginalVideoUnavailable',
  // #7892: safety-filter explanation on the video detail screen. Translation
  // deferred to the next l10n pass.
  'videoDetailHiddenBySettingsTitle',
  'videoDetailHiddenByHostFilterBody',
  'videoDetailHiddenByContentFilterBody',
  'videoDetailHiddenShowAnyway',
  'videoDetailHiddenOpenSettings',
  'videoDetailHiddenByProvenanceFilterBody',
  'safetySettingsShowVerifiedOnly',
  'safetySettingsShowVerifiedOnlySubtitle',
  // Restricted-account deletion guidance tracked in #7879.
  'shareMenuDeleteFailedAccountRestricted',
  // Account-deletion and recovery copy translation tracked in #7879.
  'accountDeletionAttemptCancelled',
  'accountDeletionCancelAttempt',
  'accountDeletionCancelAttemptBody',
  'accountDeletionRecoveryBodyWithExpiry',
  'accountDeletionSignOut',
  'accountDeletionTerminalFailureBody',
  // Translation pass tracked in #7632.
  'analyticsConnectionIssue',
  'analyticsDiagnosticsFailedSources',
  'analyticsServerUnavailable',
  // Social-counts explainer copy is new; translation pass tracked in #7632.
  'analyticsSocialCountsInfoLabel',
  'analyticsSocialCountsInfoTitle',
  'analyticsFollowerCountsBody',
  'analyticsSocialCountsLearnMore',
  'analyticsSocialCountsLearnMoreSemantics',
  // Account restore failure copy is new; translation pass tracked in #7659.
  'authAccountRestoreFailed',
  'settingsAccountRestoreFailed',
  'settingsAccountRestoreFailedSwitchMessage',
  // Commercial disclosure copy, deliberately not machine-translated: a
  // softened rendering discloses nothing. Translation pass tracked in #7673,
  // and required before any non-English campaign.
  'exploreFeaturedSponsoredBy',
  'exploreFeaturedSponsoredPillSemanticLabel',
  // Secure-account key-conflict recovery copy is new; translation pass
  // tracked in #7984.
  'authSecureAccountAlreadyRegistered',
  // OG Beta Tester explainer copy is new; translation pass tracked in #7947.
  // Only the body is deferred — the label ships mirrored verbatim. Note that
  // is not a precedent the "OG Viner" family actually sets: app_pt.arb has
  // "Viner OG" and app_de.arb has "OG Viner" for classicVinersTitle, so
  // translators do adapt these. #7947 should add both this key and
  // profileBadgeOgVinerBody to _profileBadgeSheetKeys below, which already
  // guards the sheet against English fallback and covers neither today.
  'profileBadgeOgBetaTesterBody',
  // Create-account marketing opt-in translation is deferred until the locale
  // pass for this new consent copy.
  'authCreateAccountMarketingOptIn',
  // The four social-proof keys and searchUserVideoCount left this list when
  // this branch translated them into every locale.
};

const _profileBadgeSheetKeys = <String>{
  'profileBadgeAwardedBy',
  'profileBadgeRecipients',
  'profileBadgeMoreRecipients',
  'profileBadgeSemanticLabel',
  'profileBadgeFooterBody',
  'profileBadgeFooterLink',
};

// "Badge" is the word these languages actually use, so matching English here
// is a translation rather than a gap. Every other locale localizes the noun.
const _profileBadgeFallbackSemanticLabelEnglishLocales = <String>{
  'app_de.arb',
  'app_fil.arb',
  'app_fr.arb',
  'app_it.arb',
  'app_nl.arb',
};

const _signatureVerificationKeys = <String>{
  'nostrSettingsSignatureVerification',
  'nostrSettingsSignatureVerificationIntro',
  'nostrSettingsSignatureVerificationAll',
  'nostrSettingsSignatureVerificationAllSubtitle',
  'nostrSettingsSignatureVerificationUntrusted',
  'nostrSettingsSignatureVerificationUntrustedSubtitle',
  'nostrSettingsSignatureVerificationNonDivine',
  'nostrSettingsSignatureVerificationNonDivineSubtitle',
};

Map<String, Object?> _readArb(File file) {
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

Set<String> _messageKeys(Map<String, Object?> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).toSet();
}

Set<String> _declaredPlaceholders(Map<String, Object?> arb, String key) {
  final metadata = arb['@$key'];
  if (metadata is! Map) return const {};
  final placeholders = metadata['placeholders'];
  if (placeholders is! Map) return const {};
  return placeholders.keys.map((name) => name.toString()).toSet();
}

RegExp _placeholderPattern(String name) {
  return RegExp(r'\{\s*' + RegExp.escape(name) + r'\s*\}');
}
