// ABOUTME: Selects Direct or Rooms without changing either conversation list.
// ABOUTME: Each instance belongs to one account and saves its local preference.

import 'package:bloc/bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/messages_preference_service.dart';

enum MessagesSection { direct, rooms }

class MessagesNavigationCubit extends Cubit<MessagesSection>
    with CloseGuardedEmit<MessagesSection> {
  MessagesNavigationCubit({
    required String account,
    required MessagesPreferenceService preferences,
  }) : _account = account,
       _preferences = preferences,
       super(
         preferences.roomsSelected(account)
             ? MessagesSection.rooms
             : MessagesSection.direct,
       );

  final String _account;
  final MessagesPreferenceService _preferences;

  Future<void> select(MessagesSection section) async {
    if (isClosed || section == state) return;
    emitIfOpen(section);
    try {
      await _preferences.selectRooms(
        _account,
        selected: section == MessagesSection.rooms,
      );
    } on Object catch (error, stackTrace) {
      if (!isClosed) addError(error, stackTrace);
    }
  }
}
