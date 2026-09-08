// ABOUTME: Coordinates opening native support and reports when email fallback is needed
// ABOUTME: Keeps asynchronous support orchestration out of the widget layer

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/support_contact/support_contact_state.dart';
import 'package:openvine/services/zendesk_support_service.dart';

export 'package:openvine/blocs/support_contact/support_contact_state.dart';

typedef OpenSupportMessages = Future<bool> Function();

class SupportContactCubit extends Cubit<SupportContactState>
    with CloseGuardedEmit<SupportContactState> {
  SupportContactCubit({OpenSupportMessages? openSupportMessages})
    : _openSupportMessages =
          openSupportMessages ?? ZendeskSupportService.showTicketListScreen,
      super(const SupportContactState());

  final OpenSupportMessages _openSupportMessages;

  Future<void> open() async {
    if (state.status == SupportContactStatus.opening) return;
    emitIfOpen(
      const SupportContactState(status: SupportContactStatus.opening),
    );

    final opened = await _openSupportMessages();
    emitIfOpen(
      SupportContactState(
        status: opened
            ? SupportContactStatus.opened
            : SupportContactStatus.unavailable,
      ),
    );
  }
}
