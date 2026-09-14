// ABOUTME: Opens native support and falls back to a pre-addressed support email
// ABOUTME: Keeps asynchronous support orchestration out of the widget layer

import 'dart:ui' show Rect;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/support_contact/support_contact_state.dart';
import 'package:openvine/services/support_email_composer.dart';
import 'package:openvine/services/zendesk_support_service.dart';

export 'package:openvine/blocs/support_contact/support_contact_state.dart';

typedef OpenSupportMessages = Future<bool> Function();
typedef ComposeSupportEmail = Future<void> Function({
  required String toEmail,
  required String subject,
  required String body,
  Rect? sharePositionOrigin,
});
typedef SupportMessagesAvailable = bool Function();

class SupportContactEmailRequest {
  const SupportContactEmailRequest({
    required this.toEmail,
    required this.subject,
    required this.body,
    required this.messagingUnavailableNote,
    required this.messagingFailedNote,
    this.sharePositionOrigin,
  });

  final String toEmail;
  final String subject;
  final String body;
  final String messagingUnavailableNote;
  final String messagingFailedNote;
  final Rect? sharePositionOrigin;
}

class SupportContactCubit extends Cubit<SupportContactState>
    with CloseGuardedEmit<SupportContactState> {
  SupportContactCubit({
    OpenSupportMessages? openSupportMessages,
    ComposeSupportEmail? composeEmail,
    SupportMessagesAvailable? supportMessagesAvailable,
  }) : _openSupportMessages =
           openSupportMessages ?? ZendeskSupportService.showTicketListScreen,
       _composeEmail = composeEmail ?? SupportEmailComposer().compose,
       _supportMessagesAvailable =
           supportMessagesAvailable ??
           (openSupportMessages != null ? _alwaysAvailable : _zendeskAvailable),
       super(const SupportContactState());

  final OpenSupportMessages _openSupportMessages;
  final ComposeSupportEmail _composeEmail;
  final SupportMessagesAvailable _supportMessagesAvailable;

  static bool _alwaysAvailable() => true;
  static bool _zendeskAvailable() => ZendeskSupportService.isAvailable;

  Future<void> open(SupportContactEmailRequest emailRequest) async {
    if (state.status == SupportContactStatus.opening) return;
    emitIfOpen(
      const SupportContactState(status: SupportContactStatus.opening),
    );

    try {
      if (await _openSupportMessages()) {
        emitIfOpen(
          const SupportContactState(
            status: SupportContactStatus.messagingOpened,
          ),
        );
        return;
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
    if (isClosed) return;

    // Zendesk initializes in the deferred startup phase, and the opener
    // waits for that to settle before answering. Reading availability only
    // now, rather than at construction, keeps a screen built during that
    // window from skipping messaging that is about to become available.
    final fallbackNote = _supportMessagesAvailable()
        ? emailRequest.messagingFailedNote
        : emailRequest.messagingUnavailableNote;

    try {
      await _composeEmail(
        toEmail: emailRequest.toEmail,
        subject: emailRequest.subject,
        body: '$fallbackNote\n\n${emailRequest.body}',
        sharePositionOrigin: emailRequest.sharePositionOrigin,
      );
      emitIfOpen(
        const SupportContactState(status: SupportContactStatus.emailOpened),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        const SupportContactState(status: SupportContactStatus.emailFailed),
      );
    }
  }
}
