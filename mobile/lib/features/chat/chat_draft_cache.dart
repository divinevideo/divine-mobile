// ABOUTME: Retains the active account's room drafts across catalog refreshes.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/chat/chat_composer_cubit.dart';

final chatDraftCacheProvider =
    Provider<Map<(String, String, String), ChatComposerState>>((ref) {
      return {};
    });
