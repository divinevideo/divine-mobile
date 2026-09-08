// ABOUTME: Coordinates opening native support and reports when email fallback is needed
// ABOUTME: Keeps asynchronous support orchestration out of the widget layer

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/support_contact/support_contact_state.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:unified_logger/unified_logger.dart';

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

    bool opened;
    try {
      opened = await _openSupportMessages();
    } catch (error) {
      // A throwing opener must not strand the tile on `opening` (spinner up,
      // tap disabled, and the fallback listener never sees `unavailable`) —
      // that is the #8921 failure this cubit exists to prevent. Treat a throw
      // as unavailable so the email fallback fires.
      Log.warning(
        'SupportContactCubit: opening support threw, using email fallback: '
        '$error',
        category: LogCategory.system,
      );
      emitIfOpen(
        const SupportContactState(status: SupportContactStatus.unavailable),
      );
      return;
    }

    emitIfOpen(
      SupportContactState(
        status: opened
            ? SupportContactStatus.opened
            : SupportContactStatus.unavailable,
      ),
    );
  }
}
