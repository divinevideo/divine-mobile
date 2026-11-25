// ABOUTME: Shares one project importer so repeat taps cannot race a save.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/documents_path_provider.dart';
import 'package:openvine/services/draft_transfer_service.dart';

final draftTransferServiceProvider = Provider<DraftTransferService>(
  (ref) =>
      DraftTransferService(documentsPath: ref.watch(documentsPathProvider)),
);
