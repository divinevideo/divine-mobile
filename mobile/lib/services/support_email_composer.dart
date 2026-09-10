import 'dart:ui' show Rect;

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);
typedef AndroidChooserLauncher = Future<void> Function(Uri uri, String title);
typedef ShareTextLauncher = Future<void> Function(
  String text, {
  String? subject,
  Rect? sharePositionOrigin,
});

typedef SupportEmailCompose = Future<void> Function({
  required String toEmail,
  required String subject,
  required String body,
  Rect? sharePositionOrigin,
});

String _buildFallbackShareText({
  required String toEmail,
  required String subject,
  required String body,
}) {
  return 'To: $toEmail\n'
      'Subject: $subject\n\n'
      '$body';
}

/// Launches a support email compose flow with platform-appropriate handoff.
///
/// On Android, this uses an explicit chooser around `ACTION_SENDTO` so the
/// user can pick an installed email app. On other platforms, it launches the
/// `mailto:` URI directly and falls back to the native share sheet if no mail
/// client is available.
class SupportEmailComposer {
  SupportEmailComposer({
    Future<bool> Function(Uri uri)? externalUriLauncher,
    Future<void> Function(Uri uri, String title)? androidChooserLauncher,
    ShareTextLauncher? shareTextLauncher,
  }) : _externalUriLauncher =
           externalUriLauncher ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       _androidChooserLauncher =
           androidChooserLauncher ??
           ((uri, title) {
             final intent = AndroidIntent(
               action: 'android.intent.action.SENDTO',
               data: uri.toString(),
             );
             return intent.launchChooser(title);
           }),
       _shareTextLauncher =
           shareTextLauncher ??
           ((text, {subject, sharePositionOrigin}) async {
             await showShareSheetAtOrigin(
               ShareParams(text: text, subject: subject),
               sharePositionOrigin: sharePositionOrigin,
             );
           });

  final ExternalUriLauncher _externalUriLauncher;
  final AndroidChooserLauncher _androidChooserLauncher;
  final ShareTextLauncher _shareTextLauncher;

  /// [sharePositionOrigin] anchors the iOS share-sheet popover used as the
  /// fallback when no mail client handles the `mailto:` URI. iPad idiom
  /// rejects the share without it, so widget-layer callers resolve it with
  /// `shareAnchorForContext` before calling.
  Future<void> compose({
    required String toEmail,
    required String subject,
    required String body,
    String chooserTitle = 'Choose email app',
    Rect? sharePositionOrigin,
  }) async {
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body);
    final mailtoUri = Uri.parse(
      'mailto:$toEmail?subject=$encodedSubject&body=$encodedBody',
    );

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _androidChooserLauncher(mailtoUri, chooserTitle);
        return;
      }

      final launched = await _externalUriLauncher(mailtoUri);
      if (launched) return;

      Log.warning(
        'Support email compose returned false, falling back to share sheet',
        name: 'SupportEmailComposer',
        category: LogCategory.ui,
      );
    } catch (error) {
      Log.warning(
        'Support email compose failed: $error. Falling back to share sheet',
        name: 'SupportEmailComposer',
        category: LogCategory.ui,
      );
    }

    await _shareTextLauncher(
      _buildFallbackShareText(toEmail: toEmail, subject: subject, body: body),
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
