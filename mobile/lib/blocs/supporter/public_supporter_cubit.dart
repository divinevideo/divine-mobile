// ABOUTME: Public profile recognition using only explicitly opted-in accounts.
// ABOUTME: Never uses authenticated membership data for someone else's profile.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/supporter_api_client.dart';

class PublicSupporterCubit extends Cubit<bool> with CloseGuardedEmit<bool> {
  PublicSupporterCubit({
    required SupporterApiClient client,
    required String pubkey,
  }) : _client = client,
       _pubkey = pubkey,
       super(false);

  final SupporterApiClient _client;
  final String _pubkey;

  Future<void> load() async {
    emitIfOpen(await _client.fetchPublicRecognition(_pubkey));
  }
}
